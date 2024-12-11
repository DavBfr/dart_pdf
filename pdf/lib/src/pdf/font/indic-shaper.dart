import 'package:collection/collection.dart';

import 'gsub_parser.dart';
import 'ttf_parser.dart';

getCoverageIndex(int char, Coverage coverage) {
  if (coverage.format == 2 && coverage.rangeRecords != null) {
    for (var record in coverage.rangeRecords!) {
      if (char >= record.start && char <= record.end) {
        return record.startCoverageIndex + (char - record.start);
      }
    }
  } else if (coverage.format == 1 && coverage.glyphs != null) {
    return coverage.glyphs!.contains(char) ? null : -1;
  }
  return -1;
}

doLigatureSubstitution(List<int> charIndexes, int i, LigatureSet ligature) {
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

List<int> doSubstitution(List<int> charIndexes, int i, Lookup lookup) {
  for (var table in lookup.subTables) {
    if (table is LigatureSubstitution) {
      var index = getCoverageIndex(charIndexes[i], table.coverage);
      if (index != -1) {
        if (index == null) {
          for (var ligature in table.ligatureSet) {
            charIndexes = doLigatureSubstitution(charIndexes, i, ligature);
          }
        } else {
          charIndexes =
              doLigatureSubstitution(charIndexes, i, table.ligatureSet[index]);
        }
      }
    }
  }
  return charIndexes;
}

doGlobalSubstitution(List<int> charIndexes, TtfParser font) {
  if (font.gsub != null) {
    final lookups = font.gsub!.lookupList.lookups;
    for (int i = 0; i < charIndexes.length; i++) {
      lookups.forEach((lookup) {
        if (lookup.lookupType == 4) {
          charIndexes = doSubstitution(charIndexes, i, lookup);
        }
      });
    }
  }
  return charIndexes;
}

initialReorder(List<int> glyphIndexes, String lang) {
  for (int i = 0; i < glyphIndexes.length; i++) {
    var glyphIndex = glyphIndexes[i];
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
    }
  }
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
  }
  return '';
}

indicShaper(List<int> glyphIndexes, TtfParser font) {
  var lang = getLang(font.fontName);
  glyphIndexes = doGlobalSubstitution(glyphIndexes, font);
  glyphIndexes = initialReorder(glyphIndexes, lang);
  glyphIndexes = finalReorder(glyphIndexes, lang);
  return glyphIndexes;
}
