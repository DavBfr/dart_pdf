import 'package:collection/collection.dart';

import 'gsub_parser.dart';
import 'ttf_parser.dart';

class OTProcessor {
  TtfParser font;
  OTProcessor({required this.font});

  /* OT Utils */

  getCoverageIndex(int char, Coverage coverage) {
    if (coverage.format == 2 && coverage.rangeRecords != null) {
      for (var record in coverage.rangeRecords!) {
        if (char >= record.start && char <= record.end) {
          return record.startCoverageIndex + (char - record.start);
        }
      }
    } else if (coverage.format == 1 && coverage.glyphs != null) {
      return coverage.glyphs!.contains(char) ? coverage.glyphs!.indexOf(char) : -1;
    }
    return -1;
  }

  List<Lookup> lookupsForFeatures(List<String> stage, Map<String, FeatureRecord> features) {
    var lookups = [];
    for(var s in stage) {
      FeatureRecord? feature = features[s];
      if (feature != null) {
        for(var lookupIndex in feature.feature.lookupListIndexes) {
          var lookup = font.gsub!.lookupList.lookups[lookupIndex];
          lookups.add({
            'feature': feature.featureTag,
            'index': lookupIndex,
            'lookup': lookup
          });
        }
      }
    }
    lookups.sort((a, b) => a['index'] - b['index']);
    return lookups.map((l) => l['lookup'] as Lookup).toList();
  }

  applyLookups(List<Lookup> lookups, List<int> charIndexes) {
    for (int i = 0; i < charIndexes.length; i++) {
      for(Lookup lookup in lookups) {
        for(var subTable in lookup.subTables) {
          charIndexes = applyLookup(charIndexes, i, lookup.lookupType, subTable);
        }
      }
    }
    return charIndexes;
  }

  applyLookupList(List<int> charIndexes, List<LookupRecord> records) {
    for(var record in records) {
      var lookup = font.gsub!.lookupList.lookups[record.lookupListIndex];
      for(var i = record.sequenceIndex; i < charIndexes.length; i++) {
        for(var table in lookup.subTables) {
          applyLookup(charIndexes, i, lookup.lookupType, table);
        }
      }
    }
  }

  applyLookup(List<int> charIndexes, int i, int lookupType, dynamic table) {
    if (lookupType == 1) {
      // Single Substitution
      charIndexes = doSingleSubstitution(charIndexes, i, table);
    } else if (lookupType == 4) {
      // Ligature Substitution
      charIndexes = doLigatureSubstitution(charIndexes, i, table);
    } else if (lookupType == 6) {
      // Chaining Contextual Substitution
      charIndexes = doChainingSubstitution(charIndexes, i, table);
    }
    return charIndexes;
  }

/* Single Substitution */

  List<int> doSingleSubstitution(List<int> charIndexes, int i, dynamic table) {
    if (table is SingleSubstitution) {
      var index = getCoverageIndex(charIndexes[i], table.coverage);
      if (index != -1) {
        if (table.substFormat == 1) {
          charIndexes[i] = charIndexes[i] + table.deltaGlyphID! & 0xffff;
        } else if (table.substFormat == 2 && table.substitute != null) {
          charIndexes[i] = table.substitute!.elementAt(index);
        }
      }
    }
    return charIndexes;
  }

/* Ligature Substitution */

  doLigatureSet(List<int> charIndexes, int i, LigatureSet ligature) {
    for (var l in ligature.ligatures) {
      if (i + l.components.length < charIndexes.length &&
          ListEquality().equals(
              charIndexes.sublist(i + 1, i + 1 + l.components.length),
              l.components)) {
        return [
          ...charIndexes.sublist(0, i),
          l.glyph,
          ...charIndexes.sublist(i + l.components.length + 1)
        ];
      }
    }
    return charIndexes;
  }

  List<int> doLigatureSubstitution(List<int> charIndexes, int i, dynamic table) {
    if (table is LigatureSubstitution) {
      var index = getCoverageIndex(charIndexes[i], table.coverage);
      if (index != -1) {
        if (index == null) {
          for (var ligature in table.ligatureSet) {
            charIndexes = doLigatureSet(charIndexes, i, ligature);
          }
        } else {
          charIndexes =
              doLigatureSet(charIndexes, i, table.ligatureSet[index]);
        }
      }
    }
    return charIndexes;
  }

/* Chaining Substitution */

  List<int> doChainingSubstitution(List<int> charIndexes, int i, dynamic table) {
    if (table is ChainingContext) {
      if (table.substFormat == 1) {
        var index = getCoverageIndex(charIndexes[i], table.coverage!);
        if (index != -1) {
          ChainRuleSets? set = table.chainRuleSets?[index];
          if (set != null) {
            for (ChainRule rule in set.chainRules) {
              applyLookupList(charIndexes, rule.lookupRecords);
            }
          }
        }
      }
    }
    return charIndexes;
  }
}

/* Shaper Setup */

initialReorder(List<int> glyphIndexes, String lang) {
  try {
    for (int i = 0; i < glyphIndexes.length; i++) {
      var glyphIndex = glyphIndexes[i];
      int? nextGlyphIndex = i + 1 >= glyphIndexes.length ? null : glyphIndexes[i + 1];
      if (i != 0) {
        if (lang == 'tamil') {
          if (glyphIndex == 47 || glyphIndex == 46 || glyphIndex == 48) {
            // ெ ை ே
            glyphIndexes[i] = glyphIndexes[i - 1];
            glyphIndexes[i - 1] = glyphIndex;
          }
        } else if (lang == 'hindi') {
          if (glyphIndex == 67) {
            glyphIndexes[i] = glyphIndexes[i - 1];
            glyphIndexes[i - 1] = glyphIndex;
          }
        } else if (lang == 'telugu') {
          if (glyphIndex == 73 && nextGlyphIndex != null) {
            glyphIndexes[i] = glyphIndexes[i + 2];
            glyphIndexes[i + 1] = glyphIndex;
            glyphIndexes[i + 2] = nextGlyphIndex ?? -1;
            i = i + 2;
          }
        }
      }
    }
  } catch (e) {}
  return glyphIndexes;
}

finalReorder(List<int> glyphIndexes, String lang) {
  for (int i = 0; i < glyphIndexes.length; i++) {
    var glyphIndex = glyphIndexes[i];
    if (lang == 'tamil') {
      if (glyphIndex == 49) {
        glyphIndexes.replaceRange(i - 1, i + 1, [46, glyphIndexes[i - 1], 41]);
      } else if (glyphIndex == 50) {
        glyphIndexes.replaceRange(i - 1, i + 1, [47, glyphIndexes[i - 1], 41]);
      } else if (glyphIndex == 51) {
        glyphIndexes.replaceRange(i - 1, i + 1, [46, glyphIndexes[i - 1], 54]);
      }
    }
  }
  return glyphIndexes;
}

getLang(String fontName) {
  if (fontName.toLowerCase().contains('tamil')) {
    return 'tamil';
  } else if (fontName.toLowerCase().contains('devanagari')) {
    return 'hindi';
  } else if (fontName.toLowerCase().contains('telugu')) {
    return 'telugu';
  }
  return '';
}

isIndicShaperSupported(String lang) {
  return ['tamil', 'hindi', 'telugu'].contains(lang);
}

setupStages() {
  List<dynamic> stages = [];
  stages.add(['locl', 'ccmp']);
  stages.add(['locl', 'ccmp']);
  stages.add(initialReorder);
  stages.add(['nukt']);
  stages.add(['akhn']);
  stages.add(['rphf']);
  stages.add(['rkrf']);
  stages.add(['pref']);
  stages.add(['blwf']);
  stages.add(['abvf']);
  stages.add(['half']);
  stages.add(['pstf']);
  stages.add(['vatu']);
  stages.add(['cjct']);
  stages.add(['cfar']);
  stages.add(finalReorder);
  stages.add(['pres', 'abvs', 'blws', 'psts', 'haln', 'dist', 'abvm', 'blwm', 'calt', 'clig']);
  return stages;
}

Map<String, FeatureRecord> getFeatureMap(TtfParser font) {
  Map<String, FeatureRecord> features = {};
  for(var record in font.gsub!.featureList.featureRecords) {
    features['${record.featureTag}'] = record;
  }
  return features;
}

indicShaper(List<int> glyphIndexes, TtfParser font) {
  var lang = getLang(font.fontName);
  if (isIndicShaperSupported(lang)) {
    var features = getFeatureMap(font);
    var stages = setupStages();
    for(var stage in stages) {
      if (stage is Function(List<int>, String)) {
        glyphIndexes = stage(glyphIndexes, lang);
      } else if (stage is List<String>) {
        OTProcessor ot = OTProcessor(font: font);
        List<Lookup> lookups = ot.lookupsForFeatures(stage, features);
        glyphIndexes = ot.applyLookups(lookups, glyphIndexes);
      }
    }
  }
  return glyphIndexes;
}