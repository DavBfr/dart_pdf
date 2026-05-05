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

/// Malayalam Unicode range: U+0D00 – U+0D7F

// --- Character classification ---

/// Malayalam consonants: U+0D15 – U+0D39, U+0D54 – U+0D56
bool _isConsonant(int c) =>
    (c >= 0x0D15 && c <= 0x0D39) || (c >= 0x0D54 && c <= 0x0D56);

/// Malayalam independent vowels: U+0D05 – U+0D14
bool _isVowel(int c) => c >= 0x0D05 && c <= 0x0D14;

/// Malayalam virama (chandrakkala): U+0D4D
bool _isVirama(int c) => c == 0x0D4D;

/// Post-base dependent vowel signs (rendered to the right or below)
/// U+0D3E ാ, U+0D3F ി, U+0D40 ീ, U+0D41 ു, U+0D42 ൂ,
/// U+0D43 ൃ, U+0D44 ൄ, U+0D57 ൗ (au length mark)
bool _isPostBaseMatra(int c) =>
    (c >= 0x0D3E && c <= 0x0D44) || c == 0x0D57;

/// Pre-base dependent vowel signs (rendered to the left of base)
/// U+0D46 െ, U+0D47 േ, U+0D48 ൈ
bool _isPreBaseMatra(int c) => c >= 0x0D46 && c <= 0x0D48;

/// Two-part dependent vowel signs (have both pre and post components)
/// U+0D4A ൊ, U+0D4B ോ, U+0D4C ൌ
bool _isTwoPartMatra(int c) => c >= 0x0D4A && c <= 0x0D4C;

/// Any dependent vowel sign (matra)
bool _isMatra(int c) =>
    _isPostBaseMatra(c) || _isPreBaseMatra(c) || _isTwoPartMatra(c);

/// Anusvara (U+0D02), Visarga (U+0D03), Chandrabindu (U+0D01, U+0D00)
bool _isModifier(int c) => c >= 0x0D00 && c <= 0x0D03;

/// Chillu characters: U+0D7A – U+0D7F
bool _isChillu(int c) => c >= 0x0D7A && c <= 0x0D7F;

/// Zero Width Joiner
bool _isZWJ(int c) => c == 0x200D;

/// Zero Width Non-Joiner
bool _isZWNJ(int c) => c == 0x200C;

/// Any Malayalam character
bool isMalayalamChar(int c) =>
    (c >= 0x0D00 && c <= 0x0D7F) || _isZWJ(c) || _isZWNJ(c);

/// Check if a string contains any Malayalam characters
bool containsMalayalam(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0D00 && rune <= 0x0D7F) return true;
  }
  return false;
}

// --- Two-part matra decomposition ---

/// Decompose a two-part matra into its pre-base and post-base components.
/// Returns null if not a two-part matra.
List<int>? _decomposeTwoPartMatra(int c) {
  switch (c) {
    case 0x0D4A: // ൊ = െ + ാ
      return [0x0D46, 0x0D3E];
    case 0x0D4B: // ോ = േ + ാ
      return [0x0D47, 0x0D3E];
    case 0x0D4C: // ൌ = െ + ൗ
      return [0x0D46, 0x0D57];
    default:
      return null;
  }
}

// --- Syllable cluster identification ---

/// A syllable cluster is the unit of shaping.
/// Structure: (C + Virama)* + C + Matra? + Modifier*
/// Or: Vowel + Modifier*
/// Or: Chillu
class _SyllableCluster {
  _SyllableCluster(this.codepoints);

  final List<int> codepoints;
}

/// Parse text into syllable clusters for reordering.
List<_SyllableCluster> _parseClusters(List<int> codepoints) {
  final clusters = <_SyllableCluster>[];
  var current = <int>[];

  void flushCluster() {
    if (current.isNotEmpty) {
      clusters.add(_SyllableCluster(List.from(current)));
      current.clear();
    }
  }

  var i = 0;
  while (i < codepoints.length) {
    final c = codepoints[i];

    if (_isConsonant(c)) {
      // Start a new cluster if current doesn't end with virama
      if (current.isNotEmpty &&
          !current.any((x) => _isVirama(x)) &&
          current.any((x) => _isConsonant(x) || _isVowel(x))) {
        // Check if previous cluster ended properly (no trailing virama)
        final lastNonModifier = current.lastIndexWhere(
          (x) => !_isModifier(x) && !_isZWJ(x) && !_isZWNJ(x),
        );
        if (lastNonModifier >= 0 && !_isVirama(current[lastNonModifier])) {
          flushCluster();
        }
      }
      current.add(c);
      i++;

      // Consume virama + consonant sequences (conjuncts)
      while (i < codepoints.length) {
        if (_isVirama(codepoints[i])) {
          current.add(codepoints[i]);
          i++;
          // After virama, check for ZWJ/ZWNJ
          if (i < codepoints.length &&
              (_isZWJ(codepoints[i]) || _isZWNJ(codepoints[i]))) {
            current.add(codepoints[i]);
            i++;
          }
          // After virama (+ZWJ/ZWNJ), check for consonant
          if (i < codepoints.length && _isConsonant(codepoints[i])) {
            current.add(codepoints[i]);
            i++;
          } else {
            break;
          }
        } else {
          break;
        }
      }

      // Consume matra
      if (i < codepoints.length && _isMatra(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      // Consume modifiers (anusvara, visarga, etc.)
      while (i < codepoints.length && _isModifier(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      flushCluster();
    } else if (_isVowel(c)) {
      flushCluster();
      current.add(c);
      i++;

      // Consume matra after vowel (rare but possible)
      if (i < codepoints.length && _isMatra(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      // Consume modifiers
      while (i < codepoints.length && _isModifier(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      flushCluster();
    } else if (_isChillu(c)) {
      flushCluster();
      current.add(c);
      i++;
      flushCluster();
    } else {
      // Non-Malayalam character — single-char cluster
      flushCluster();
      current.add(c);
      i++;
      flushCluster();
    }
  }

  flushCluster();
  return clusters;
}

// --- Reordering ---

/// Reorder a single syllable cluster for correct visual rendering.
List<int> _reorderCluster(List<int> codepoints) {
  if (codepoints.length <= 1) return codepoints;

  // Step 1: Decompose two-part matras
  final decomposed = <int>[];
  int? preBaseFromTwoPart;
  int? postBaseFromTwoPart;

  for (final c in codepoints) {
    final parts = _decomposeTwoPartMatra(c);
    if (parts != null) {
      preBaseFromTwoPart = parts[0];
      postBaseFromTwoPart = parts[1];
      // Don't add yet — will be positioned later
    } else {
      decomposed.add(c);
    }
  }

  // Step 2: Find the base consonant position
  // Base is typically the last consonant before the matra
  var basePos = -1;
  for (var i = decomposed.length - 1; i >= 0; i--) {
    if (_isConsonant(decomposed[i])) {
      basePos = i;
      break;
    }
  }

  if (basePos < 0) {
    // No consonant found — just reassemble
    if (preBaseFromTwoPart != null && postBaseFromTwoPart != null) {
      return [...decomposed, preBaseFromTwoPart, postBaseFromTwoPart];
    }
    return decomposed;
  }

  // Step 3: Separate pre-base matras and reorder
  final result = <int>[];
  final preBaseMatras = <int>[];
  final postParts = <int>[];

  for (var i = 0; i < decomposed.length; i++) {
    final c = decomposed[i];
    if (_isPreBaseMatra(c)) {
      preBaseMatras.add(c);
    } else {
      postParts.add(c);
    }
  }

  // Step 4: Find the base consonant in postParts
  var newBasePos = -1;
  for (var i = 0; i < postParts.length; i++) {
    if (_isConsonant(postParts[i])) {
      // Find the FIRST consonant that starts the cluster
      newBasePos = i;
      break;
    }
  }

  if (newBasePos < 0) newBasePos = 0;

  // Step 5: Insert pre-base matras BEFORE the base consonant cluster
  for (var i = 0; i < postParts.length; i++) {
    if (i == newBasePos) {
      // Insert pre-base matras from decomposed two-part matras
      if (preBaseFromTwoPart != null) {
        result.add(preBaseFromTwoPart);
      }
      // Insert pre-base matras
      result.addAll(preBaseMatras);
    }
    result.add(postParts[i]);
  }

  // If base was not found (shouldn't happen), append matras at end
  if (newBasePos < 0) {
    if (preBaseFromTwoPart != null) {
      result.add(preBaseFromTwoPart);
    }
    result.addAll(preBaseMatras);
  }

  // Append post-base part of two-part matra
  if (postBaseFromTwoPart != null) {
    result.add(postBaseFromTwoPart);
  }

  return result;
}

/// Apply Malayalam character reordering to a list of Unicode codepoints.
/// This handles:
/// 1. Syllable cluster identification
/// 2. Two-part matra decomposition
/// 3. Pre-base matra reordering
/// 4. ZWJ/ZWNJ preservation
List<int> reorder(List<int> codepoints) {
  final clusters = _parseClusters(codepoints);
  final result = <int>[];

  for (final cluster in clusters) {
    // Only reorder clusters that contain Malayalam characters
    if (cluster.codepoints.any(
      (c) => _isConsonant(c) || _isVowel(c),
    )) {
      result.addAll(_reorderCluster(cluster.codepoints));
    } else {
      result.addAll(cluster.codepoints);
    }
  }

  return result;
}

/// The ordered list of GSUB features to apply for Malayalam shaping.
const List<String> malayalamFeatures = [
  'locl', // Localized forms
  'nukt', // Nukta forms
  'akhn', // Akhand (mandatory conjuncts)
  'rphf', // Reph forms
  'blwf', // Below-base forms
  'pstf', // Post-base forms
  'half', // Half forms
  'pref', // Pre-base forms
  'abvs', // Above-base substitutions
  'blws', // Below-base substitutions
  'psts', // Post-base substitutions
  'pres', // Pre-base substitutions
  'liga', // Standard ligatures
  'clig', // Contextual ligatures
];
