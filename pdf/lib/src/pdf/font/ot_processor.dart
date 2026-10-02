import './layout/script.dart';
import 'glyph_info.dart';
import 'glyph_iterator.dart';
import 'gsub_parser.dart';
import 'ttf_parser.dart';

const DEFAULT_SCRIPTS = ['DFLT', 'dflt', 'latn'];

class OTProcessor {
  OTProcessor(this.font, this.table) {
    initScript();
    this.selectScript();
  }
  int currentIndex = 0;
  final TtfParser font;
  final dynamic table;
  int variationsIndex = -1;
  ScriptTable? script;
  String? scriptTag;
  LangSysTable? language;
  String? languageTag;
  String direction = 'ltr';
  late GlyphIterator glyphIterator;
  late Map<String, FeatureTable> features;
  String? currentFeature;
  List<GlyphInfo> glyphs = [];
  List<dynamic> positions = [];
  int ligatureID = -1;

  ScriptRecord? findScript(dynamic script) {
    if (this.table.scriptList == null || script == null) {
      return null;
    }

    if (!(script is List)) {
      script = [script];
    }

    for (var s in script) {
      for (var entry in this.table.scriptList.scriptRecords) {
        if (entry.tag == s) {
          return entry;
        }
      }
    }
    return null;
  }

  selectScript([String? script, String? language, String? direction]) {
    var changed = false;
    if (this.script == null || script != this.scriptTag) {
      var entry = this.findScript(script ?? DEFAULT_SCRIPTS);

      if (entry == null) {
        return this.scriptTag;
      }

      this.scriptTag = entry.tag;
      this.script = entry.scriptTable;
      this.language = null;
      this.languageTag = null;
      changed = true;
    }

    if (direction == null || direction != this.direction) {
      this.direction = direction ?? getDirection(script);
    }

    if (language != null && language.length < 4) {
      int spaceNeeded = 4 - language.length;
      if (spaceNeeded > 0) {
        language += ' ' * spaceNeeded;
      }
    }

    if (language == null || language != this.languageTag) {
      this.language = null;

      if (this.script != null) {
        for (var lang in this.script!.langSysRecords) {
          if (lang.langSysTag == language) {
            this.language = lang.langSys;
            this.languageTag = lang.langSysTag;
            break;
          }
        }
      }

      if (this.language == null) {
        this.language = this.script?.defaultLangSys;
        this.languageTag = null;
      }

      changed = true;
    }

    // Build a feature lookup table
    if (changed) {
      this.features = {};
      if (this.language != null) {
        for (var featureIndex in this.language!.featureIndexes) {
          var record = this.table.featureList.featureRecords[featureIndex];
          var substituteFeature =
              this.substituteFeatureForVariations(featureIndex);
          this.features[record.featureTag] =
              substituteFeature ?? record.feature;
        }
      }
    }

    return this.scriptTag;
  }

  List<Map<String, dynamic>> lookupsForFeatures(List<String>? userFeatures,
      [List<int>? exclude]) {
    List<Map<String, dynamic>> lookups = [];
    for (var tag in (userFeatures ?? [])) {
      var feature = this.features[tag];
      if (feature == null) {
        continue;
      }

      for (var lookupIndex in feature.lookupListIndexes) {
        if (exclude != null && exclude.indexOf(lookupIndex) != -1) {
          continue;
        }

        lookups.add({
          'feature': tag,
          'index': lookupIndex,
          'lookup': this.table.lookupList.lookups[lookupIndex]
        });
      }
    }

    lookups.sort((a, b) => a['index'].compareTo(b['index']));
    return lookups;
  }

  substituteFeatureForVariations(featureIndex) {
    if (this.variationsIndex == -1) {
      return null;
    }

    var record = this
        .table
        .featureVariations
        .featureVariationRecords[this.variationsIndex];
    var substitutions = record.featureTableSubstitution.substitutions;
    for (var substitution in substitutions) {
      if (substitution.featureIndex == featureIndex) {
        return substitution.alternateFeatureTable;
      }
    }

    return null;
  }

  findVariationsIndex(coords) {
    var variations = this.table.featureVariations;
    if (variations == null) {
      return -1;
    }

    var records = variations.featureVariationRecords;
    for (int i = 0; i < records.length; i++) {
      var conditions = records[i].conditionSet.conditionTable;
      if (this.variationConditionsMatch(conditions, coords)) {
        return i;
      }
    }

    return -1;
  }

  variationConditionsMatch(List<dynamic> conditions, coords) {
    return conditions.every((condition) {
      var coord =
          condition.axisIndex < coords.length ? coords[condition.axisIndex] : 0;
      return condition.filterRangeMinValue <= coord &&
          coord <= condition.filterRangeMaxValue;
    });
  }

  applyFeatures(List<String>? userFeatures, List<GlyphInfo> glyphs,
      List<dynamic> advances) {
    var lookups = this.lookupsForFeatures(userFeatures);
    this.applyLookups(lookups, glyphs, advances);
  }

  applyLookups(List<Map<String, dynamic>> lookups, List<GlyphInfo> glyphs,
      List<dynamic> positions) {
    this.glyphs = glyphs;
    this.positions = positions;
    this.glyphIterator = GlyphIterator(glyphs);

    for (var l in lookups) {
      String feature = l['feature']!;
      Lookup lookup = l['lookup']!;
      this.currentFeature = feature;

      this.glyphIterator.reset(lookup.flags);

      while (this.glyphIterator.index < glyphs.length) {
        if (!(this.glyphIterator.cur.features[feature] ?? false)) {
          this.glyphIterator.next();
          continue;
        }

        for (var table in lookup.subTables) {
          var res = this.applyLookup(lookup.lookupType, table);
          if (res) {
            break;
          }
        }

        this.glyphIterator.next();
      }
    }
  }

  bool applyLookup(int lookupType, SubTable table) {
    throw 'applyLookup must be implemented by subclasses';
  }

  applyLookupList(List<LookupRecord> lookupRecords) {
    var options = this.glyphIterator.options;
    var glyphIndex = this.glyphIterator.index;

    for (var lookupRecord in lookupRecords) {
      // Reset flags and find glyph index for this lookup record
      this.glyphIterator.reset(options, glyphIndex);
      this.glyphIterator.increment(lookupRecord.sequenceIndex);

      // Get the lookup and setup flags for subtables
      var lookup = this.table.lookupList.lookups[lookupRecord.lookupListIndex];
      this.glyphIterator.reset(lookup.flags, this.glyphIterator.index);

      // Apply lookup subtables until one matches
      for (var table in lookup.subTables) {
        if (this.applyLookup(lookup.lookupType, table)) {
          break;
        }
      }
    }

    this.glyphIterator.reset(options, glyphIndex);
    return true;
  }

  int coverageIndex(Coverage coverage, [int? glyph]) {
    if (glyph == null) {
      glyph = this.glyphIterator.cur.id;
    }

    if (coverage.glyphs != null && coverage.glyphs!.length > 0) {
      return coverage.glyphs!.indexOf(glyph);
    }
    if (coverage.rangeRecords != null && coverage.rangeRecords!.length > 0) {
      for (var range in coverage.rangeRecords!) {
        if (range.start <= glyph && glyph <= range.end) {
          return range.startCoverageIndex + glyph - range.start;
        }
      }
    }
    return -1;
  }

  bool match(int sequenceIndex, List<dynamic> sequence,
      bool Function(dynamic, GlyphInfo) fn) {
    var pos = this.glyphIterator.index;
    GlyphInfo? glyph = this.glyphIterator.increment(sequenceIndex);
    var idx = 0;

    while (idx < sequence.length && glyph != null && fn(sequence[idx], glyph)) {
      idx++;
      glyph = this.glyphIterator.next();
    }

    this.glyphIterator.index = pos;
    if (idx < sequence.length) {
      return false;
    }

    return true;
  }

  List<int>? matchMatched(int sequenceIndex, List<dynamic> sequence,
      bool Function(dynamic, GlyphInfo) fn, List<int> matched) {
    var pos = this.glyphIterator.index;
    GlyphInfo? glyph = this.glyphIterator.increment(sequenceIndex);
    var idx = 0;

    while (idx < sequence.length && glyph != null && fn(sequence[idx], glyph)) {
      matched.add(this.glyphIterator.index);
      idx++;
      glyph = this.glyphIterator.next();
    }

    this.glyphIterator.index = pos;
    if (idx < sequence.length) {
      return null;
    }

    return matched;
  }

  sequenceMatches(int sequenceIndex, List<dynamic> sequence) {
    return this.match(sequenceIndex, sequence,
        (component, GlyphInfo glyph) => component == glyph.id);
  }

  sequenceMatchIndices(int sequenceIndex, List<dynamic> sequence) {
    return this.matchMatched(sequenceIndex, sequence,
        (component, GlyphInfo glyph) {
      // If the current feature doesn't apply to this glyph,
      if (!(glyph.features[this.currentFeature] != null &&
          glyph.features[this.currentFeature]!)) {
        return false;
      }

      return component == glyph.id;
    }, []);
  }

  coverageSequenceMatches(int sequenceIndex, List<dynamic> sequence) {
    return this.match(
      sequenceIndex,
      sequence,
      (coverage, GlyphInfo glyph) =>
          this.coverageIndex(coverage, glyph.id) >= 0,
    );
  }

  static getClassID(int glyph, ClassDef classDef) {
    switch (classDef.classDefFormat) {
      case 1: // Class array
        int i = glyph - classDef.startGlyph!;
        if (i >= 0 && i < classDef.classValueArray!.length) {
          return classDef.classValueArray![i];
        }
        break;
      case 2:
        for (var range in classDef.classRangeRecord!) {
          if (range.start <= glyph && glyph <= range.end) {
            return range.classValue;
          }
        }
        break;
    }

    return 0;
  }

  classSequenceMatches(sequenceIndex, sequence, classDef) {
    return this.match(
      sequenceIndex,
      sequence,
      (classID, glyph) => classID == OTProcessor.getClassID(glyph.id, classDef),
    );
  }

  applyContext(dynamic table) {
    int index = 0;
    dynamic set;
    switch (table.version) {
      case 1:
        index = this.coverageIndex(table.coverage);
        if (index == -1) {
          return false;
        }

        set = table.ruleSets[index];
        for (var rule in set) {
          if (this.sequenceMatches(1, rule.input)) {
            return this.applyLookupList(rule.lookupRecords);
          }
        }

        break;

      case 2:
        if (this.coverageIndex(table.coverage) == -1) {
          return false;
        }

        index =
            OTProcessor.getClassID(this.glyphIterator.cur.id, table.classDef);
        if (index == -1) {
          return false;
        }

        set = table.classSet[index];
        for (var rule in set) {
          if (this.classSequenceMatches(1, rule.classes, table.classDef)) {
            return this.applyLookupList(rule.lookupRecords);
          }
        }

        break;

      case 3:
        if (this.coverageSequenceMatches(0, table.coverages)) {
          return this.applyLookupList(table.lookupRecords);
        }

        break;
    }

    return false;
  }

  applyChainingContext(dynamic table) {}
}
