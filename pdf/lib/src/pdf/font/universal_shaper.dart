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

import 'gpos_parser.dart';
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

/// Result of shaping text — contains the glyph IDs, positioning
/// adjustments, and the script that was detected.
class ShapingResult {
  const ShapingResult(this.glyphIds, this.scriptTags, [this.positions]);

  final List<int> glyphIds;
  final List<String> scriptTags;

  /// Per-glyph positioning adjustments from GPOS.
  /// null if no GPOS data was found.
  final List<GlyphPosition>? positions;
}

/// A run of codepoints that all belong to the same script.
class _ScriptRun {
  _ScriptRun(this.codepoints, this.indicConfig, this.nonIndicScript);

  final List<int> codepoints;
  final indic.ScriptConfig? indicConfig;
  final _NonIndicScript? nonIndicScript;

  bool get isCommon => indicConfig == null && nonIndicScript == null;
  bool get isIndic => indicConfig != null;
  bool get isNonIndic => nonIndicScript != null;
}

/// Segment codepoints into runs by script.
/// Common characters (Latin, numbers, punctuation, spaces) get their own
/// runs that are passed through without shaping.
List<_ScriptRun> _segmentByScript(List<int> codepoints) {
  final runs = <_ScriptRun>[];
  if (codepoints.isEmpty) return runs;

  var currentCps = <int>[];
  indic.ScriptConfig? currentIndic;
  _NonIndicScript? currentNonIndic;
  var currentIsCommon = true;

  void flushRun() {
    if (currentCps.isNotEmpty) {
      runs.add(_ScriptRun(
        List.from(currentCps),
        currentIndic,
        currentNonIndic,
      ));
      currentCps.clear();
    }
  }

  for (final cp in codepoints) {
    final indicScript = indic.detectScript(cp);
    final nonIndicScript = indicScript == null ? _detectNonIndic(cp) : null;
    final isCommon = indicScript == null && nonIndicScript == null;

    if (isCommon) {
      // Common characters (Latin, space, punctuation) —
      // continue the current run
      currentCps.add(cp);
    } else if (indicScript != null) {
      // Indic character
      if (!currentIsCommon && currentIndic != indicScript) {
        // Different Indic script — start new run
        flushRun();
      } else if (currentIsCommon && currentCps.isNotEmpty) {
        // Was common, now switching to Indic — flush common
        flushRun();
      }
      currentIndic = indicScript;
      currentNonIndic = null;
      currentIsCommon = false;
      currentCps.add(cp);
    } else {
      // Non-Indic complex script
      if (!currentIsCommon && currentNonIndic != nonIndicScript) {
        flushRun();
      } else if (currentIsCommon && currentCps.isNotEmpty) {
        flushRun();
      }
      currentIndic = null;
      currentNonIndic = nonIndicScript;
      currentIsCommon = false;
      currentCps.add(cp);
    }
  }

  flushRun();
  return runs;
}

/// Shape complex script text using per-script-run segmentation.
///
/// Segments the text into runs of the same script, shapes each
/// independently with the correct reordering + GSUB rules, then
/// concatenates the results. This correctly handles mixed text
/// like "Hello नमस्ते தமிழ் World".
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

  final runs = _segmentByScript(codepoints);

  // If no run has a complex script, no shaping needed
  final hasComplex = runs.any((r) => !r.isCommon);
  if (!hasComplex) return null;

  final allGlyphIds = <int>[];
  var primaryScriptTags = <String>[];

  for (final run in runs) {
    if (run.isCommon) {
      // Common text (Latin, spaces, etc.) — just convert to glyph IDs
      allGlyphIds.addAll(run.codepoints.map(charToGlyph));
    } else if (run.isIndic) {
      // Indic script: reorder + GSUB
      final reordered = indic.reorder(run.codepoints);
      var glyphIds = reordered.map(charToGlyph).toList();

      final gsubData = font.getGsubData(run.indicConfig!.scriptTags);
      if (gsubData != null) {
        glyphIds = gsubData.applyFeatures(
          glyphIds,
          indic.indicGsubFeatures,
        );
      }

      allGlyphIds.addAll(glyphIds);
      if (primaryScriptTags.isEmpty) {
        primaryScriptTags = run.indicConfig!.scriptTags;
      }
    } else if (run.isNonIndic) {
      // Non-Indic: GSUB-only
      var glyphIds = run.codepoints.map(charToGlyph).toList();

      final gsubData = font.getGsubData(run.nonIndicScript!.scriptTags);
      if (gsubData != null) {
        glyphIds = gsubData.applyFeatures(
          glyphIds,
          run.nonIndicScript!.features,
        );
      }

      allGlyphIds.addAll(glyphIds);
      if (primaryScriptTags.isEmpty) {
        primaryScriptTags = run.nonIndicScript!.scriptTags;
      }
    }
  }

  // Apply GPOS positioning
  List<GlyphPosition>? positions;
  if (primaryScriptTags.isNotEmpty) {
    final gposData = font.getGposData(primaryScriptTags);
    if (gposData != null) {
      positions = gposData.position(allGlyphIds);
    }
  }

  return ShapingResult(allGlyphIds, primaryScriptTags, positions);
}
