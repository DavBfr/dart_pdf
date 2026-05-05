/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'gsub_parser.dart';
import 'indic.dart' as indic;
import 'ttf_parser.dart';

/// Non-Indic complex scripts that benefit from GSUB-only shaping.
/// These scripts don't need character reordering, but their fonts
/// contain GSUB tables with ligatures and contextual substitutions.
class _NonIndicScript {
  const _NonIndicScript(this.name, this.rangeStart, this.rangeEnd,
      this.scriptTags, this.features);

  final String name;
  final int rangeStart;
  final int rangeEnd;
  final List<String> scriptTags;
  final List<String> features;
}

const _nonIndicScripts = [
  _NonIndicScript('Sinhala', 0x0D80, 0x0DFF, ['sinh'],
      ['locl', 'akhn', 'blwf', 'pstf', 'pres', 'abvs', 'blws', 'psts', 'liga']),
  _NonIndicScript('Thai', 0x0E00, 0x0E7F, ['thai'],
      ['locl', 'liga', 'ccmp']),
  _NonIndicScript('Lao', 0x0E80, 0x0EFF, ['lao '],
      ['locl', 'liga', 'ccmp']),
  _NonIndicScript('Tibetan', 0x0F00, 0x0FFF, ['tibt'],
      ['locl', 'abvs', 'blws', 'liga', 'ccmp']),
  _NonIndicScript('Myanmar', 0x1000, 0x109F, ['mym2', 'mymr'],
      ['locl', 'rphf', 'pref', 'blwf', 'pstf', 'pres', 'abvs', 'blws', 'psts', 'liga']),
  _NonIndicScript('Khmer', 0x1780, 0x17FF, ['khmr'],
      ['locl', 'pref', 'blwf', 'pstf', 'pres', 'abvs', 'blws', 'psts', 'liga', 'clig']),
];

/// Detect if a codepoint belongs to a non-Indic complex script.
_NonIndicScript? _detectNonIndic(int codepoint) {
  for (final script in _nonIndicScripts) {
    if (codepoint >= script.rangeStart && codepoint <= script.rangeEnd) {
      return script;
    }
  }
  return null;
}

/// Check if a string contains any complex script characters
/// (either Indic or non-Indic).
bool containsComplexScript(String text) {
  for (final rune in text.runes) {
    if (indic.detectScript(rune) != null) return true;
    if (_detectNonIndic(rune) != null) return true;
  }
  return false;
}

/// Result of shaping text — contains the glyph IDs and the script
/// that was detected.
class ShapingResult {
  const ShapingResult(this.glyphIds, this.scriptTags);

  final List<int> glyphIds;
  final List<String> scriptTags;
}

/// Shape complex script text using character reordering + GSUB.
///
/// Returns the shaped glyph ID sequence, or null if no shaping was applied.
///
/// [text] — the input text
/// [font] — the TtfParser for the font
/// [charToGlyph] — function to map a codepoint to a glyph ID
ShapingResult? shapeText(
  String text,
  TtfParser font,
  int Function(int codepoint) charToGlyph,
) {
  final codepoints = text.runes.toList();
  if (codepoints.isEmpty) return null;

  // Try Indic script detection first
  indic.ScriptConfig? indicConfig;
  for (final cp in codepoints) {
    indicConfig = indic.detectScript(cp);
    if (indicConfig != null) break;
  }

  if (indicConfig != null) {
    // Indic script: reorder + GSUB
    final reordered = indic.reorder(codepoints);
    final glyphIds = reordered.map(charToGlyph).toList();

    // Apply GSUB
    final gsubData = font.getGsubData(indicConfig.scriptTags);
    if (gsubData != null) {
      final shaped = gsubData.applyFeatures(
        glyphIds,
        indic.indicGsubFeatures,
      );
      return ShapingResult(shaped, indicConfig.scriptTags);
    }

    return ShapingResult(glyphIds, indicConfig.scriptTags);
  }

  // Try non-Indic complex script detection
  _NonIndicScript? nonIndicScript;
  for (final cp in codepoints) {
    nonIndicScript = _detectNonIndic(cp);
    if (nonIndicScript != null) break;
  }

  if (nonIndicScript != null) {
    // Non-Indic: GSUB-only (no character reordering)
    final glyphIds = codepoints.map(charToGlyph).toList();

    final gsubData = font.getGsubData(nonIndicScript.scriptTags);
    if (gsubData != null) {
      final shaped = gsubData.applyFeatures(
        glyphIds,
        nonIndicScript.features,
      );
      return ShapingResult(shaped, nonIndicScript.scriptTags);
    }

    return ShapingResult(glyphIds, nonIndicScript.scriptTags);
  }

  return null;
}
