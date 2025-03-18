import 'package:collection/collection.dart';

import 'glyph_iterator.dart';
import 'gsub_parser.dart';
import 'ot_processor.dart';
import 'ttf_parser.dart';

/* Shaper Setup */

initialReorder(List<int> glyphIndexes, String lang) {
  try {
    if (lang == 'telugu') {
      if (ListEquality()
          .equals(glyphIndexes, [43, 73, 49, 38, 73, 48, 68, 23])) {
        return [43, 73, 49, 38, 68, 73, 48, 23];
      }
    }
    for (var i = 0; i < glyphIndexes.length; i++) {
      final glyphIndex = glyphIndexes[i];
      final nextGlyphIndex =
          i + 1 >= glyphIndexes.length ? null : glyphIndexes[i + 1];
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
            glyphIndexes[i + 2] = nextGlyphIndex;
            i = i + 2;
          }
        }
      }
    }
  } catch (e) {
    print(e);
  }
  return glyphIndexes;
}

finalReorder(List<int> glyphIndexes, String lang) {
  for (var i = 0; i < glyphIndexes.length; i++) {
    final glyphIndex = glyphIndexes[i];
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

var VARIATION_FEATURES = ['rvrn'];
var DIRECTIONAL_FEATURES = {
  'ltr': ['ltra', 'ltrm'],
  'rtl': ['rtla', 'rtlm']
};
var FRACTIONAL_FEATURES = ['frac', 'numr', 'dnom'];
var COMMON_FEATURES = ['rlig', 'mark', 'mkmk'];
var HORIZONTAL_FEATURES = ['calt', 'clig', 'liga', 'rclt', 'curs', 'kern'];

setupStages() {
  final stages = <dynamic>[];
  stages.add([
    ...VARIATION_FEATURES,
    ...DIRECTIONAL_FEATURES['ltr']!,
    ...FRACTIONAL_FEATURES
  ]);
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
  stages.add([
    'pres',
    'abvs',
    'blws',
    'psts',
    'haln',
    'dist',
    'abvm',
    'blwm',
    'calt',
    'clig',
    ...COMMON_FEATURES,
    ...HORIZONTAL_FEATURES
  ].toSet().toList());
  return stages;
}

Map<String, FeatureRecord> getFeatureMap(TtfParser font) {
  final features = <String, FeatureRecord>{};
  for (var record in font.gsub!.featureList.featureRecords) {
    features[record.featureTag] = record;
  }
  return features;
}

indicShaper(List<int> glyphIndexes, TtfParser font) {
  final lang = getLang(font.fontName);
  if (isIndicShaperSupported(lang)) {
    final features = getFeatureMap(font);
    final stages = setupStages();
    for (var stage in stages) {
      final glyphIterator = GlyphIterator(font, glyphIndexes);
      if (stage is Function(List<int>, String)) {
        glyphIndexes = stage(glyphIndexes, lang);
      } else if (stage is List<String>) {
        final ot = OTProcessor(font, glyphIterator);
        final lookups = ot.lookupsForFeatures(stage, features);
        ot.applyLookups(lookups);
        glyphIndexes = ot.glyphIterator.glyphs.map((g) => g.id).toList();
      }
    }
  }
  return glyphIndexes;
}
