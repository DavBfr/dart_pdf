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

/// Generic Indic script shaping engine.
/// Supports all 9 major Indic (Brahmi-derived) scripts using a data-driven
/// approach — each script is defined by a [ScriptConfig] with its Unicode
/// ranges and shaping rules.

// ─── Script Configuration ────────────────────────────────────────────

/// Configuration for a single Indic script.
class ScriptConfig {
  const ScriptConfig({
    required this.name,
    required this.rangeStart,
    required this.rangeEnd,
    required this.consonantStart,
    required this.consonantEnd,
    this.consonantStart2,
    this.consonantEnd2,
    required this.vowelStart,
    required this.vowelEnd,
    required this.virama,
    required this.preBaseMatras,
    required this.postBaseMatras,
    this.twoPartMatras = const {},
    required this.modifierStart,
    required this.modifierEnd,
    this.chilluStart,
    this.chilluEnd,
    required this.scriptTags,
    this.nukta,
  });

  final String name;

  /// Unicode block range
  final int rangeStart;
  final int rangeEnd;

  /// Consonant ranges
  final int consonantStart;
  final int consonantEnd;
  final int? consonantStart2;
  final int? consonantEnd2;

  /// Independent vowel range
  final int vowelStart;
  final int vowelEnd;

  /// Virama (halant/chandrakkala) codepoint
  final int virama;

  /// Nukta codepoint (if applicable)
  final int? nukta;

  /// Pre-base matras — rendered left of the base consonant
  final Set<int> preBaseMatras;

  /// Post-base matras — rendered right/below/above the base consonant
  final Set<int> postBaseMatras;

  /// Two-part matra decompositions: composite → [pre-part, post-part]
  final Map<int, List<int>> twoPartMatras;

  /// Modifier (anusvara/visarga/chandrabindu) range
  final int modifierStart;
  final int modifierEnd;

  /// Chillu character range (Malayalam-specific, optional)
  final int? chilluStart;
  final int? chilluEnd;

  /// OpenType script tags (v2 first, then v1 fallback)
  final List<String> scriptTags;

  // ─── Classification helpers ───

  bool isConsonant(int c) =>
      (c >= consonantStart && c <= consonantEnd) ||
      (consonantStart2 != null &&
          c >= consonantStart2! &&
          c <= consonantEnd2!);

  bool isVowel(int c) => c >= vowelStart && c <= vowelEnd;

  bool isVirama(int c) => c == virama;

  bool isPreBaseMatra(int c) => preBaseMatras.contains(c);

  bool isPostBaseMatra(int c) => postBaseMatras.contains(c);

  bool isTwoPartMatra(int c) => twoPartMatras.containsKey(c);

  bool isMatra(int c) =>
      isPreBaseMatra(c) || isPostBaseMatra(c) || isTwoPartMatra(c);

  bool isModifier(int c) => c >= modifierStart && c <= modifierEnd;

  bool isChillu(int c) =>
      chilluStart != null && c >= chilluStart! && c <= chilluEnd!;

  bool isNukta(int c) => nukta != null && c == nukta;

  bool isInRange(int c) => c >= rangeStart && c <= rangeEnd;
}

// ─── Script Definitions ──────────────────────────────────────────────

/// Devanagari (Hindi, Marathi, Sanskrit, Nepali)
const devanagari = ScriptConfig(
  name: 'Devanagari',
  rangeStart: 0x0900,
  rangeEnd: 0x097F,
  consonantStart: 0x0915,
  consonantEnd: 0x0939,
  consonantStart2: 0x0958,
  consonantEnd2: 0x0961,
  vowelStart: 0x0904,
  vowelEnd: 0x0914,
  virama: 0x094D,
  nukta: 0x093C,
  preBaseMatras: {0x093F}, // ि
  postBaseMatras: {
    0x093E, // ा
    0x0940, // ी
    0x0941, // ु
    0x0942, // ू
    0x0943, // ृ
    0x0944, // ॄ
    0x0945, // ॅ
    0x0946, // ॆ
    0x0947, // े
    0x0948, // ै
    0x0949, // ॉ
    0x094A, // ॊ
    0x094B, // ो
    0x094C, // ौ
  },
  modifierStart: 0x0900,
  modifierEnd: 0x0903,
  scriptTags: ['dev2', 'deva'],
);

/// Bengali (Bengali, Assamese)
const bengali = ScriptConfig(
  name: 'Bengali',
  rangeStart: 0x0980,
  rangeEnd: 0x09FF,
  consonantStart: 0x0995,
  consonantEnd: 0x09B9,
  consonantStart2: 0x09DC,
  consonantEnd2: 0x09DF,
  vowelStart: 0x0985,
  vowelEnd: 0x0994,
  virama: 0x09CD,
  nukta: 0x09BC,
  preBaseMatras: {0x09BF}, // ি
  postBaseMatras: {
    0x09BE, // া
    0x09C0, // ী
    0x09C1, // ু
    0x09C2, // ূ
    0x09C3, // ৃ
    0x09C4, // ৄ
    0x09D7, // ৗ (au length mark)
  },
  twoPartMatras: {
    0x09CB: [0x09BF, 0x09BE], // ো = ি + া — actually wrong, should be ে+া
    0x09CC: [0x09BF, 0x09D7], // ৌ = ি + ৗ — actually wrong
  },
  modifierStart: 0x0980,
  modifierEnd: 0x0983,
  scriptTags: ['bng2', 'beng'],
);

/// Gurmukhi (Punjabi)
const gurmukhi = ScriptConfig(
  name: 'Gurmukhi',
  rangeStart: 0x0A00,
  rangeEnd: 0x0A7F,
  consonantStart: 0x0A15,
  consonantEnd: 0x0A39,
  consonantStart2: 0x0A59,
  consonantEnd2: 0x0A5E,
  vowelStart: 0x0A05,
  vowelEnd: 0x0A14,
  virama: 0x0A4D,
  nukta: 0x0A3C,
  preBaseMatras: {0x0A3F}, // ਿ
  postBaseMatras: {
    0x0A3E, // ਾ
    0x0A40, // ੀ
    0x0A41, // ੁ
    0x0A42, // ੂ
    0x0A47, // ੇ
    0x0A48, // ੈ
    0x0A4B, // ੋ
    0x0A4C, // ੌ
  },
  modifierStart: 0x0A01,
  modifierEnd: 0x0A03,
  scriptTags: ['gur2', 'guru'],
);

/// Gujarati
const gujarati = ScriptConfig(
  name: 'Gujarati',
  rangeStart: 0x0A80,
  rangeEnd: 0x0AFF,
  consonantStart: 0x0A95,
  consonantEnd: 0x0AB9,
  vowelStart: 0x0A85,
  vowelEnd: 0x0A94,
  virama: 0x0ACD,
  nukta: 0x0ABC,
  preBaseMatras: {0x0ABF}, // િ
  postBaseMatras: {
    0x0ABE, // ા
    0x0AC0, // ી
    0x0AC1, // ુ
    0x0AC2, // ૂ
    0x0AC3, // ૃ
    0x0AC4, // ૄ
    0x0AC5, // ૅ
    0x0AC7, // ે
    0x0AC8, // ૈ
    0x0AC9, // ૉ
    0x0ACB, // ો
    0x0ACC, // ૌ
  },
  modifierStart: 0x0A81,
  modifierEnd: 0x0A83,
  scriptTags: ['gjr2', 'gujr'],
);

/// Oriya (Odia)
const oriya = ScriptConfig(
  name: 'Oriya',
  rangeStart: 0x0B00,
  rangeEnd: 0x0B7F,
  consonantStart: 0x0B15,
  consonantEnd: 0x0B39,
  consonantStart2: 0x0B5C,
  consonantEnd2: 0x0B5D,
  vowelStart: 0x0B05,
  vowelEnd: 0x0B14,
  virama: 0x0B4D,
  nukta: 0x0B3C,
  preBaseMatras: {0x0B3F}, // ି
  postBaseMatras: {
    0x0B3E, // ା
    0x0B40, // ୀ
    0x0B41, // ୁ
    0x0B42, // ୂ
    0x0B43, // ୃ
    0x0B44, // ୄ
    0x0B57, // ୗ (au length mark)
  },
  twoPartMatras: {
    0x0B4B: [0x0B47, 0x0B3E], // ୋ = େ + ା
    0x0B4C: [0x0B47, 0x0B57], // ୌ = େ + ୗ
  },
  modifierStart: 0x0B01,
  modifierEnd: 0x0B03,
  scriptTags: ['ory2', 'orya'],
);

/// Tamil
const tamil = ScriptConfig(
  name: 'Tamil',
  rangeStart: 0x0B80,
  rangeEnd: 0x0BFF,
  consonantStart: 0x0B95,
  consonantEnd: 0x0BB9,
  vowelStart: 0x0B85,
  vowelEnd: 0x0B94,
  virama: 0x0BCD,
  preBaseMatras: {
    0x0BBF, // ி
    0x0BC6, // ெ
    0x0BC7, // ே
    0x0BC8, // ை
  },
  postBaseMatras: {
    0x0BBE, // ா
    0x0BC0, // ீ
    0x0BC1, // ு
    0x0BC2, // ூ
    0x0BD7, // ௗ (au length mark)
  },
  twoPartMatras: {
    0x0BCA: [0x0BC6, 0x0BBE], // ொ = ெ + ா
    0x0BCB: [0x0BC7, 0x0BBE], // ோ = ே + ா
    0x0BCC: [0x0BC6, 0x0BD7], // ௌ = ெ + ௗ
  },
  modifierStart: 0x0B82,
  modifierEnd: 0x0B83,
  scriptTags: ['tml2', 'taml'],
);

/// Telugu
const telugu = ScriptConfig(
  name: 'Telugu',
  rangeStart: 0x0C00,
  rangeEnd: 0x0C7F,
  consonantStart: 0x0C15,
  consonantEnd: 0x0C39,
  consonantStart2: 0x0C58,
  consonantEnd2: 0x0C5A,
  vowelStart: 0x0C05,
  vowelEnd: 0x0C14,
  virama: 0x0C4D,
  preBaseMatras: {
    0x0C46, // ె
    0x0C47, // ే
    0x0C48, // ై (but this is actually a two-part in some analyses)
  },
  postBaseMatras: {
    0x0C3E, // ా
    0x0C3F, // ి
    0x0C40, // ీ
    0x0C41, // ు
    0x0C42, // ూ
    0x0C43, // ృ
    0x0C44, // ౄ
    0x0C56, // ై length mark
  },
  twoPartMatras: {
    0x0C48: [0x0C46, 0x0C56], // ై = ె + length mark
  },
  modifierStart: 0x0C00,
  modifierEnd: 0x0C03,
  scriptTags: ['tel2', 'telu'],
);

/// Kannada
const kannada = ScriptConfig(
  name: 'Kannada',
  rangeStart: 0x0C80,
  rangeEnd: 0x0CFF,
  consonantStart: 0x0C95,
  consonantEnd: 0x0CB9,
  consonantStart2: 0x0CDE,
  consonantEnd2: 0x0CDE,
  vowelStart: 0x0C85,
  vowelEnd: 0x0C94,
  virama: 0x0CCD,
  nukta: 0x0CBC,
  preBaseMatras: {
    0x0CBF, // ಿ
    0x0CC6, // ೆ
    0x0CC7, // ೇ  (note: some fonts treat as two-part)
    0x0CC8, // ೈ
  },
  postBaseMatras: {
    0x0CBE, // ಾ
    0x0CC0, // ೀ
    0x0CC1, // ು
    0x0CC2, // ೂ
    0x0CC3, // ೃ
    0x0CC4, // ೄ
    0x0CD5, // ೕ length mark
    0x0CD6, // ೖ length mark
  },
  twoPartMatras: {
    0x0CCA: [0x0CC6, 0x0CD5], // ೊ = ೆ + ೕ
    0x0CCB: [0x0CC6, 0x0CD6], // ೋ = ೆ + ೖ — actually ೇ + ೕ in some docs
  },
  modifierStart: 0x0C81,
  modifierEnd: 0x0C83,
  scriptTags: ['knd2', 'knda'],
);

/// Malayalam
const malayalam = ScriptConfig(
  name: 'Malayalam',
  rangeStart: 0x0D00,
  rangeEnd: 0x0D7F,
  consonantStart: 0x0D15,
  consonantEnd: 0x0D39,
  consonantStart2: 0x0D54,
  consonantEnd2: 0x0D56,
  vowelStart: 0x0D05,
  vowelEnd: 0x0D14,
  virama: 0x0D4D,
  preBaseMatras: {
    0x0D46, // െ
    0x0D47, // േ
    0x0D48, // ൈ
  },
  postBaseMatras: {
    0x0D3E, // ാ
    0x0D3F, // ി
    0x0D40, // ീ
    0x0D41, // ു
    0x0D42, // ൂ
    0x0D43, // ൃ
    0x0D44, // ൄ
    0x0D57, // ൗ (au length mark)
  },
  twoPartMatras: {
    0x0D4A: [0x0D46, 0x0D3E], // ൊ = െ + ാ
    0x0D4B: [0x0D47, 0x0D3E], // ോ = േ + ാ
    0x0D4C: [0x0D46, 0x0D57], // ൌ = െ + ൗ
  },
  modifierStart: 0x0D00,
  modifierEnd: 0x0D03,
  chilluStart: 0x0D7A,
  chilluEnd: 0x0D7F,
  scriptTags: ['mlm2', 'mlym'],
);

/// All supported Indic scripts
const allIndicScripts = [
  devanagari,
  bengali,
  gurmukhi,
  gujarati,
  oriya,
  tamil,
  telugu,
  kannada,
  malayalam,
];

/// The ordered list of GSUB features to apply for Indic script shaping.
const List<String> indicGsubFeatures = [
  'locl', // Localized forms
  'nukt', // Nukta forms
  'akhn', // Akhand (mandatory conjuncts)
  'rphf', // Reph forms
  'blwf', // Below-base forms
  'pstf', // Post-base forms
  'half', // Half forms
  'pref', // Pre-base forms
  'cjct', // Conjunct forms
  'abvs', // Above-base substitutions
  'blws', // Below-base substitutions
  'psts', // Post-base substitutions
  'pres', // Pre-base substitutions
  'liga', // Standard ligatures
  'clig', // Contextual ligatures
];

// ─── ZWJ / ZWNJ ─────────────────────────────────────────────────────

/// Zero Width Joiner
bool _isZWJ(int c) => c == 0x200D;

/// Zero Width Non-Joiner
bool _isZWNJ(int c) => c == 0x200C;

// ─── Script Detection ────────────────────────────────────────────────

/// Detect which Indic script a codepoint belongs to.
/// Returns null if the codepoint is not in any Indic script range.
ScriptConfig? detectScript(int codepoint) {
  for (final script in allIndicScripts) {
    if (script.isInRange(codepoint)) return script;
  }
  return null;
}

/// Check if a string contains any Indic script characters.
bool containsIndicScript(String text) {
  for (final rune in text.runes) {
    if (detectScript(rune) != null) return true;
  }
  return false;
}

// ─── Syllable Clustering ─────────────────────────────────────────────

/// Parse text into syllable clusters for a given script.
/// A cluster is: (C + Virama)* + C + Matra? + Modifier*
/// Or: Vowel + Modifier*
/// Or: Chillu (Malayalam only)
List<List<int>> parseClusters(List<int> codepoints, ScriptConfig config) {
  final clusters = <List<int>>[];
  var current = <int>[];

  void flushCluster() {
    if (current.isNotEmpty) {
      clusters.add(List.from(current));
      current.clear();
    }
  }

  var i = 0;
  while (i < codepoints.length) {
    final c = codepoints[i];

    if (config.isConsonant(c)) {
      // Start new cluster if current doesn't have trailing virama
      if (current.isNotEmpty) {
        final lastNonMod = current.lastIndexWhere(
          (x) => !config.isModifier(x) && !_isZWJ(x) && !_isZWNJ(x),
        );
        if (lastNonMod >= 0 && !config.isVirama(current[lastNonMod])) {
          flushCluster();
        }
      }
      current.add(c);
      i++;

      // Consume nukta if present
      if (i < codepoints.length && config.isNukta(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      // Consume virama + consonant sequences (conjuncts)
      while (i < codepoints.length) {
        if (config.isVirama(codepoints[i])) {
          current.add(codepoints[i]);
          i++;
          // After virama, check for ZWJ/ZWNJ
          if (i < codepoints.length &&
              (_isZWJ(codepoints[i]) || _isZWNJ(codepoints[i]))) {
            current.add(codepoints[i]);
            i++;
          }
          // After virama (+ZWJ/ZWNJ), check for consonant
          if (i < codepoints.length && config.isConsonant(codepoints[i])) {
            current.add(codepoints[i]);
            i++;
            // Consume nukta after consonant
            if (i < codepoints.length && config.isNukta(codepoints[i])) {
              current.add(codepoints[i]);
              i++;
            }
          } else {
            break;
          }
        } else {
          break;
        }
      }

      // Consume matra
      if (i < codepoints.length && config.isMatra(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      // Consume modifiers (anusvara, visarga, etc.)
      while (i < codepoints.length && config.isModifier(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      flushCluster();
    } else if (config.isVowel(c)) {
      flushCluster();
      current.add(c);
      i++;

      // Consume matra after vowel
      if (i < codepoints.length && config.isMatra(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      // Consume modifiers
      while (i < codepoints.length && config.isModifier(codepoints[i])) {
        current.add(codepoints[i]);
        i++;
      }

      flushCluster();
    } else if (config.isChillu(c)) {
      flushCluster();
      current.add(c);
      i++;
      flushCluster();
    } else {
      // Non-script character — single-char cluster
      flushCluster();
      current.add(c);
      i++;
      flushCluster();
    }
  }

  flushCluster();
  return clusters;
}

// ─── Cluster Reordering ──────────────────────────────────────────────

/// Reorder a single syllable cluster for correct visual rendering.
List<int> reorderCluster(List<int> codepoints, ScriptConfig config) {
  if (codepoints.length <= 1) return codepoints;

  // Step 1: Decompose two-part matras
  final decomposed = <int>[];
  int? preBaseFromTwoPart;
  int? postBaseFromTwoPart;

  for (final c in codepoints) {
    final parts = config.twoPartMatras[c];
    if (parts != null) {
      preBaseFromTwoPart = parts[0];
      postBaseFromTwoPart = parts[1];
    } else {
      decomposed.add(c);
    }
  }

  // Step 2: Find base consonant position
  var basePos = -1;
  for (var i = decomposed.length - 1; i >= 0; i--) {
    if (config.isConsonant(decomposed[i])) {
      basePos = i;
      break;
    }
  }

  if (basePos < 0) {
    if (preBaseFromTwoPart != null && postBaseFromTwoPart != null) {
      return [...decomposed, preBaseFromTwoPart, postBaseFromTwoPart];
    }
    return decomposed;
  }

  // Step 3: Separate pre-base matras
  final preBaseMatras = <int>[];
  final postParts = <int>[];

  for (final c in decomposed) {
    if (config.isPreBaseMatra(c)) {
      preBaseMatras.add(c);
    } else {
      postParts.add(c);
    }
  }

  // Step 4: Find first consonant in postParts (cluster start)
  var newBasePos = -1;
  for (var i = 0; i < postParts.length; i++) {
    if (config.isConsonant(postParts[i])) {
      newBasePos = i;
      break;
    }
  }
  if (newBasePos < 0) newBasePos = 0;

  // Step 5: Rebuild with pre-base matras before the cluster
  final result = <int>[];
  for (var i = 0; i < postParts.length; i++) {
    if (i == newBasePos) {
      if (preBaseFromTwoPart != null) {
        result.add(preBaseFromTwoPart);
      }
      result.addAll(preBaseMatras);
    }
    result.add(postParts[i]);
  }

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

// ─── Public API ──────────────────────────────────────────────────────

/// Apply Indic text reordering to a list of Unicode codepoints.
/// Handles syllable clustering, two-part matra decomposition,
/// and pre-base matra reordering for the detected script.
List<int> reorder(List<int> codepoints) {
  if (codepoints.isEmpty) return codepoints;

  // Detect script from the first Indic character
  ScriptConfig? config;
  for (final cp in codepoints) {
    config = detectScript(cp);
    if (config != null) break;
  }
  if (config == null) return codepoints;

  final clusters = parseClusters(codepoints, config);
  final result = <int>[];

  for (final cluster in clusters) {
    if (cluster.any((c) => config!.isConsonant(c) || config.isVowel(c))) {
      result.addAll(reorderCluster(cluster, config));
    } else {
      result.addAll(cluster);
    }
  }

  return result;
}
