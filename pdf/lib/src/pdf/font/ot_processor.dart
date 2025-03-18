import 'package:collection/collection.dart';

import 'glyph_Info.dart';
import 'glyph_iterator.dart';
import 'gsub_parser.dart';
import 'ttf_parser.dart';

class OTProcessor {
  TtfParser font;
  GlyphIterator glyphIterator;
  String currentFeature = '';

  OTProcessor(this.font, this.glyphIterator);

  /* OT Utils */

  static int getClassID(int glyphIndex, ClassDef classDef) {
    if (classDef.classDefFormat == 1) {
      var i = glyphIndex - classDef.startGlyph!;
      if (i >= 0 && i < classDef.classValueArray!.length) {
        return classDef.classValueArray![i];
      }
    } else if (classDef.classDefFormat == 2) {
      for (ClassRangeRecord range in classDef.classRangeRecord!) {
        if (range.start <= glyphIndex && glyphIndex <= range.end) {
          return range.classValue;
        }
      }
    }
    return 0;
  }

  int getCoverageIndex(Coverage coverage, [int? glyph]) {
    glyph ??= glyphIterator.cur.id;
    if (coverage.format == 1 && coverage.glyphs != null) {
      return coverage.glyphs!.contains(glyph)
          ? coverage.glyphs!.indexOf(glyph)
          : -1;
    } else if (coverage.format == 2 && coverage.rangeRecords != null) {
      for (var record in coverage.rangeRecords!) {
        if (glyph >= record.start && glyph <= record.end) {
          return record.startCoverageIndex + (glyph - record.start);
        }
      }
    }
    return -1;
  }

  dynamic match<T>(
      int sequenceIndex, List<T> sequence, Function(T, GlyphInfo) fn,
      [List<int>? matched]) {
    var pos = glyphIterator.index;
    var glyph = glyphIterator.increment(sequenceIndex);
    int idx = 0;

    while (idx < sequence.length && glyph != null && fn(sequence[idx], glyph)) {
      if (matched != null) {
        matched.add(glyphIterator.index);
      }
      idx++;
      glyph = glyphIterator.next();
    }

    glyphIterator.index = pos;
    if (idx < sequence.length) {
      return false;
    }

    return matched ?? true;
  }

  sequenceMatches(int sequenceIndex, List<int> sequence) {
    return match<int>(
        sequenceIndex, sequence, (component, glyph) => component == glyph.id);
  }

  sequenceMatchIndices(int sequenceIndex, List<int> sequence) {
    return match<int>(sequenceIndex, sequence, (component, glyph) {
      // If the current feature doesn't apply to this glyph,
      // TODO: Need supported features from glyphInfo
      return component == glyph.id;
    }, []);
  }

  coverageSequenceMatches(int sequenceIndex, List<Coverage> sequence) {
    return match<Coverage>(sequenceIndex, sequence,
        (coverage, glyph) => getCoverageIndex(coverage, glyph.id) >= 0);
  }

  classSequenceMatches(
      int sequenceIndex, List<int> sequence, ClassDef classDef) {
    return match<int>(sequenceIndex, sequence,
        (classID, glyph) => classID == getClassID(glyph.id, classDef));
  }

  List<Lookup> lookupsForFeatures(
      List<String> stage, Map<String, FeatureRecord> features) {
    List<Lookup> lookups = [];
    for (var s in stage) {
      FeatureRecord? feature = features[s];
      if (feature != null) {
        for (var lookupIndex in feature.feature.lookupListIndexes) {
          final lookup = font.gsub!.lookupList.lookups[lookupIndex];
          lookup.index = lookupIndex;
          lookup.feature = feature.featureTag;
          lookups.add(lookup);
        }
      }
    }
    lookups.sort((a, b) => a.index - b.index);
    return lookups;
  }

  applyLookups(List<Lookup> lookups) {
    for (var lookup in lookups) {
      currentFeature = lookup.feature;
      glyphIterator.reset(lookup.flags);
      while (glyphIterator.index < glyphIterator.glyphs.length) {
        // TODO: Need supported features from glyphInfo
        for (var subTable in lookup.subTables) {
          final res = applyLookup(lookup.lookupType, subTable);
          if (res) {
            break;
          }
        }
        glyphIterator.next();
      }
    }
  }

  applyLookupList(List<LookupRecord> lookupRecords) {
    var options = glyphIterator.options;
    var glyphIndex = glyphIterator.index;
    for (var lookupRecord in lookupRecords) {
      // Reset flags and find glyph index for this lookup record
      glyphIterator.reset(options, glyphIndex);
      // Get the lookup and setup flags for subtables
      glyphIterator.increment(lookupRecord.sequenceIndex);

      var lookup = font.gsub!.lookupList.lookups[lookupRecord.lookupListIndex];
      // Apply lookup subtables until one matches
      glyphIterator.reset(lookup.flags, glyphIterator.index);

      for (var table in lookup.subTables) {
        if (applyLookup(lookup.lookupType, table)) {
          break;
        }
      }
    }

    glyphIterator.reset(options, glyphIndex);
    return true;
  }

  bool applyLookup(int lookupType, dynamic table) {
    if (lookupType == 1) {
      // Single Substitution
      return doSingleSubstitution(table);
    } else if (lookupType == 4) {
      // Ligature Substitution
      return doLigatureSubstitution(table);
    } else if (lookupType == 6) {
      // Chaining Contextual Substitution
      return doChainingSubstitution(table);
    }
    return false;
  }

/* Single Substitution */

  bool doSingleSubstitution(dynamic table) {
    if (table is SingleSubstitution) {
      final index = getCoverageIndex(table.coverage);
      if (index == -1) {
        return false;
      }

      final glyph = glyphIterator.cur;
      if (table.substFormat == 1) {
        glyph.id = glyph.id + table.deltaGlyphID! & 0xffff;
      } else if (table.substFormat == 2 && table.substitute != null) {
        glyph.id = table.substitute!.elementAt(index);
      }
    }
    return true;
  }

/* Ligature Substitution */

  bool doLigatureSet(LigatureSet ligature) {
    var i = glyphIterator.index;
    for (var l in ligature.ligatures) {
      var matched = sequenceMatchIndices(1, l.components);
      if ((matched is List && matched.isEmpty) || matched == false) {
        continue;
      }
      if (i + l.components.length < glyphIterator.glyphIds.length &&
          const ListEquality().equals(
              glyphIterator.glyphIds
                  .sublist(i + 1, i + 1 + l.components.length),
              l.components)) {
        var newGlyph = GlyphInfo(font, l.glyph);
        newGlyph.isLigated = true;
        newGlyph.substituted = true;
        glyphIterator.glyphs = [
          ...glyphIterator.glyphs.sublist(0, i),
          newGlyph,
          ...glyphIterator.glyphs.sublist(i + l.components.length + 1)
        ];
        glyphIterator.glyphIds = glyphIterator.glyphs.map((g) => g.id).toList();
        return true;
      }
    }
    return false;
  }

  bool doLigatureSubstitution(dynamic table) {
    if (table is LigatureSubstitution) {
      final index = getCoverageIndex(table.coverage);
      if (index == -1) {
        return false;
      }

      // TODO: Ligature substitution is simplified
      return doLigatureSet(table.ligatureSet[index]);
    }
    return false;
  }

/* Chaining Substitution */

  bool doChainingSubstitution(dynamic table) {
    if (table is ChainingContext) {
      if (table.substFormat == 1) {
        var index = getCoverageIndex(table.coverage!);
        if (index == -1) {
          return false;
        }
        ChainRuleSets? set = table.chainRuleSets?[index];
        if (set != null) {
          for (ChainRule rule in set.chainRules) {
            if (sequenceMatches(rule.backtrack.length * -1, rule.backtrack) &&
                sequenceMatches(1, rule.input) &&
                sequenceMatches(1 + rule.input.length, rule.lookahead)) {
              return applyLookupList(rule.lookupRecords);
            }
          }
        }
      } else if (table.substFormat == 2) {
        if (getCoverageIndex(table.coverage!) == -1) {
          return false;
        }
        var index = getClassID(glyphIterator.cur.id, table.inputClassDef!);
        if (index != -1) {
          ChainRuleSets? set = table.chainClassSet?[index];
          if (set == null) {
            return false;
          }

          for (ChainRule rule in set.chainRules) {
            if (classSequenceMatches(rule.backtrack.length * -1, rule.backtrack,
                    table.backtrackClassDef!) &&
                classSequenceMatches(1, rule.input, table.inputClassDef!) &&
                classSequenceMatches(1 + rule.input.length, rule.lookahead,
                    table.lookaheadClassDef!)) {
              return applyLookupList(rule.lookupRecords);
            }
          }
        }
      } else if (table.substFormat == 3) {
        if (coverageSequenceMatches(table.backtrackGlyphCount! * -1,
                table.backtrackCoverage ?? []) &&
            coverageSequenceMatches(0, table.inputCoverage!) &&
            coverageSequenceMatches(
                table.inputGlyphCount!, table.lookaheadCoverage ?? [])) {
          return applyLookupList(table.lookupRecords!);
        }
      }
    }
    return false;
  }
}
