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

import 'dart:typed_data';

/// Parsed coverage table — maps glyph IDs to coverage indices.
class CoverageTable {
  CoverageTable._(this._glyphToIndex);

  final Map<int, int> _glyphToIndex;

  /// Returns the coverage index for [glyphId], or -1 if not covered.
  int indexOf(int glyphId) => _glyphToIndex[glyphId] ?? -1;

  /// Whether [glyphId] is covered.
  bool covers(int glyphId) => _glyphToIndex.containsKey(glyphId);

  /// Parse a coverage table at [offset] in [bytes].
  factory CoverageTable.parse(ByteData bytes, int offset) {
    final format = bytes.getUint16(offset);
    final map = <int, int>{};

    if (format == 1) {
      // Format 1: Individual glyph indices
      final glyphCount = bytes.getUint16(offset + 2);
      for (var i = 0; i < glyphCount; i++) {
        final glyphId = bytes.getUint16(offset + 4 + i * 2);
        map[glyphId] = i;
      }
    } else if (format == 2) {
      // Format 2: Range records
      final rangeCount = bytes.getUint16(offset + 2);
      for (var i = 0; i < rangeCount; i++) {
        final rangeOffset = offset + 4 + i * 6;
        final startGlyphId = bytes.getUint16(rangeOffset);
        final endGlyphId = bytes.getUint16(rangeOffset + 2);
        final startCoverageIndex = bytes.getUint16(rangeOffset + 4);
        for (var g = startGlyphId; g <= endGlyphId; g++) {
          map[g] = startCoverageIndex + (g - startGlyphId);
        }
      }
    }

    return CoverageTable._(map);
  }
}

/// Parsed class definition table.
class ClassDefTable {
  ClassDefTable._(this._glyphToClass);

  final Map<int, int> _glyphToClass;

  /// Returns the class for [glyphId], or 0 (default class) if not defined.
  int classOf(int glyphId) => _glyphToClass[glyphId] ?? 0;

  /// Parse a class definition table at [offset] in [bytes].
  factory ClassDefTable.parse(ByteData bytes, int offset) {
    final format = bytes.getUint16(offset);
    final map = <int, int>{};

    if (format == 1) {
      final startGlyphId = bytes.getUint16(offset + 2);
      final glyphCount = bytes.getUint16(offset + 4);
      for (var i = 0; i < glyphCount; i++) {
        final classValue = bytes.getUint16(offset + 6 + i * 2);
        map[startGlyphId + i] = classValue;
      }
    } else if (format == 2) {
      final classRangeCount = bytes.getUint16(offset + 2);
      for (var i = 0; i < classRangeCount; i++) {
        final rangeOffset = offset + 4 + i * 6;
        final startGlyphId = bytes.getUint16(rangeOffset);
        final endGlyphId = bytes.getUint16(rangeOffset + 2);
        final classValue = bytes.getUint16(rangeOffset + 4);
        for (var g = startGlyphId; g <= endGlyphId; g++) {
          map[g] = classValue;
        }
      }
    }

    return ClassDefTable._(map);
  }
}

/// A single ligature rule: component glyph IDs → ligature glyph ID.
class LigatureRule {
  const LigatureRule(this.ligatureGlyph, this.componentGlyphIds);

  final int ligatureGlyph;

  /// The component glyph IDs (excluding the first glyph, which is
  /// identified by the coverage table).
  final List<int> componentGlyphIds;
}

/// A sequence lookup record for contextual substitutions.
class SequenceLookupRecord {
  const SequenceLookupRecord(this.sequenceIndex, this.lookupListIndex);

  final int sequenceIndex;
  final int lookupListIndex;
}

/// Abstract base for GSUB lookups.
abstract class GsubLookup {
  const GsubLookup();

  /// Apply this lookup to [glyphIds], returning the modified glyph list.
  /// [allLookups] is needed for contextual lookups that reference other lookups.
  List<int> apply(List<int> glyphIds, List<GsubLookup> allLookups);
}

/// Type 1: Single substitution — replace one glyph with another.
class SingleSubstitution extends GsubLookup {
  const SingleSubstitution(this._substitutions);

  /// Map of input glyph ID → output glyph ID.
  final Map<int, int> _substitutions;

  @override
  List<int> apply(List<int> glyphIds, List<GsubLookup> allLookups) {
    return glyphIds.map((g) => _substitutions[g] ?? g).toList();
  }
}

/// Type 4: Ligature substitution — replace multiple glyphs with one.
class LigatureSubstitution extends GsubLookup {
  const LigatureSubstitution(this._ligatureSets);

  /// Map of first glyph ID → list of ligature rules.
  final Map<int, List<LigatureRule>> _ligatureSets;

  @override
  List<int> apply(List<int> glyphIds, List<GsubLookup> allLookups) {
    final result = <int>[];
    var i = 0;

    while (i < glyphIds.length) {
      final firstGlyph = glyphIds[i];
      final rules = _ligatureSets[firstGlyph];

      if (rules != null) {
        var matched = false;

        for (final rule in rules) {
          final compCount = rule.componentGlyphIds.length;

          if (i + compCount >= glyphIds.length) {
            continue;
          }

          var matches = true;
          for (var j = 0; j < compCount; j++) {
            if (glyphIds[i + 1 + j] != rule.componentGlyphIds[j]) {
              matches = false;
              break;
            }
          }

          if (matches) {
            result.add(rule.ligatureGlyph);
            i += 1 + compCount; // skip first glyph + components
            matched = true;
            break;
          }
        }

        if (!matched) {
          result.add(firstGlyph);
          i++;
        }
      } else {
        result.add(firstGlyph);
        i++;
      }
    }

    return result;
  }
}

/// Type 6: Chaining contextual substitution.
class ChainingContextSubstitution extends GsubLookup {
  const ChainingContextSubstitution(this._rules);

  final List<ChainingContextRule> _rules;

  @override
  List<int> apply(List<int> glyphIds, List<GsubLookup> allLookups) {
    final result = List<int>.from(glyphIds);

    for (var i = 0; i < result.length; i++) {
      for (final rule in _rules) {
        final matchResult = rule.tryMatch(result, i);
        if (matchResult != null) {
          // Apply nested lookups
          for (final record in matchResult) {
            final targetIndex = i + record.sequenceIndex;
            if (targetIndex >= 0 &&
                targetIndex < result.length &&
                record.lookupListIndex < allLookups.length) {
              final lookup = allLookups[record.lookupListIndex];
              // Apply lookup to single glyph (simplified)
              final singleResult =
                  lookup.apply([result[targetIndex]], allLookups);
              if (singleResult.length == 1) {
                result[targetIndex] = singleResult[0];
              }
            }
          }
          break;
        }
      }
    }

    return result;
  }
}

/// A single rule for chaining contextual substitution.
class ChainingContextRule {
  const ChainingContextRule({
    required this.backtrackCoverages,
    required this.inputCoverages,
    required this.lookaheadCoverages,
    required this.lookupRecords,
  });

  final List<CoverageTable> backtrackCoverages;
  final List<CoverageTable> inputCoverages;
  final List<CoverageTable> lookaheadCoverages;
  final List<SequenceLookupRecord> lookupRecords;

  /// Try to match this rule at position [pos] in [glyphs].
  /// Returns the lookup records if matched, null otherwise.
  List<SequenceLookupRecord>? tryMatch(List<int> glyphs, int pos) {
    // Check input sequence
    for (var i = 0; i < inputCoverages.length; i++) {
      final idx = pos + i;
      if (idx >= glyphs.length) return null;
      if (!inputCoverages[i].covers(glyphs[idx])) return null;
    }

    // Check backtrack sequence (in reverse order)
    for (var i = 0; i < backtrackCoverages.length; i++) {
      final idx = pos - 1 - i;
      if (idx < 0) return null;
      if (!backtrackCoverages[i].covers(glyphs[idx])) return null;
    }

    // Check lookahead sequence
    for (var i = 0; i < lookaheadCoverages.length; i++) {
      final idx = pos + inputCoverages.length + i;
      if (idx >= glyphs.length) return null;
      if (!lookaheadCoverages[i].covers(glyphs[idx])) return null;
    }

    return lookupRecords;
  }
}

/// Composite lookup that wraps multiple subtable lookups.
class CompositeLookup extends GsubLookup {
  const CompositeLookup(this.subtables);

  final List<GsubLookup> subtables;

  @override
  List<int> apply(List<int> glyphIds, List<GsubLookup> allLookups) {
    var result = glyphIds;
    for (final subtable in subtables) {
      result = subtable.apply(result, allLookups);
    }
    return result;
  }
}

/// Parsed GSUB data for a font.
class GsubData {
  GsubData(this._featureLookupIndices, this._lookups);

  /// Feature tag → list of lookup indices
  final Map<String, List<int>> _featureLookupIndices;

  /// All lookups in the lookup list
  final List<GsubLookup> _lookups;

  /// Apply GSUB features to a glyph ID sequence.
  /// Features are applied in the order specified.
  List<int> applyFeatures(List<int> glyphIds, List<String> features) {
    var result = List<int>.from(glyphIds);

    for (final feature in features) {
      final lookupIndices = _featureLookupIndices[feature];
      if (lookupIndices == null) continue;

      for (final idx in lookupIndices) {
        if (idx < _lookups.length) {
          result = _lookups[idx].apply(result, _lookups);
        }
      }
    }

    return result;
  }

  /// Whether this GSUB data has any lookups for the given feature.
  bool hasFeature(String feature) =>
      _featureLookupIndices.containsKey(feature);
}

/// Parse the OpenType GSUB table from font bytes.
class GsubParser {
  GsubParser(this.bytes);

  final ByteData bytes;

  /// Parse the GSUB table starting at [tableOffset] and return
  /// the parsed data for the given [scriptTags].
  GsubData? parse(int tableOffset, List<String> scriptTags) {
    if (tableOffset == 0) return null;

    try {
      // GSUB Header
      final majorVersion = bytes.getUint16(tableOffset);
      if (majorVersion != 1) return null;

      final scriptListOffset =
          tableOffset + bytes.getUint16(tableOffset + 4);
      final featureListOffset =
          tableOffset + bytes.getUint16(tableOffset + 6);
      final lookupListOffset =
          tableOffset + bytes.getUint16(tableOffset + 8);

      // Parse all lookups first
      final lookups = _parseLookupList(lookupListOffset);

      // Find matching script
      final featureIndices =
          _findScriptFeatures(scriptListOffset, scriptTags);
      if (featureIndices == null) return null;

      // Parse feature list and map features to lookup indices
      final featureLookupMap =
          _parseFeatures(featureListOffset, featureIndices);

      return GsubData(featureLookupMap, lookups);
    } catch (e) {
      // If GSUB parsing fails, return null gracefully
      assert(() {
        print('GSUB parsing failed: $e');
        return true;
      }());
      return null;
    }
  }

  /// Find feature indices for the first matching script tag.
  List<int>? _findScriptFeatures(
    int scriptListOffset,
    List<String> scriptTags,
  ) {
    final scriptCount = bytes.getUint16(scriptListOffset);

    for (final targetTag in scriptTags) {
      for (var i = 0; i < scriptCount; i++) {
        final recordOffset = scriptListOffset + 2 + i * 6;
        final tag = _readTag(recordOffset);

        if (tag == targetTag) {
          final scriptOffset =
              scriptListOffset + bytes.getUint16(recordOffset + 4);
          return _parseScript(scriptOffset);
        }
      }
    }

    return null;
  }

  /// Parse a Script table and return feature indices from the
  /// default LangSys.
  List<int> _parseScript(int scriptOffset) {
    final defaultLangSysOffset = bytes.getUint16(scriptOffset);
    if (defaultLangSysOffset == 0) {
      // No default LangSys — try the first LangSys record
      final langSysCount = bytes.getUint16(scriptOffset + 2);
      if (langSysCount > 0) {
        final langSysOffset =
            scriptOffset + bytes.getUint16(scriptOffset + 2 + 4 + 2);
        return _parseLangSys(langSysOffset);
      }
      return [];
    }

    return _parseLangSys(scriptOffset + defaultLangSysOffset);
  }

  /// Parse a LangSys table and return all feature indices.
  List<int> _parseLangSys(int langSysOffset) {
    final requiredFeatureIndex = bytes.getUint16(langSysOffset + 2);
    final featureIndexCount = bytes.getUint16(langSysOffset + 4);

    final indices = <int>[];
    if (requiredFeatureIndex != 0xFFFF) {
      indices.add(requiredFeatureIndex);
    }

    for (var i = 0; i < featureIndexCount; i++) {
      indices.add(bytes.getUint16(langSysOffset + 6 + i * 2));
    }

    return indices;
  }

  /// Parse the FeatureList and return a map of feature tags to
  /// lookup indices, filtered by the given feature indices.
  Map<String, List<int>> _parseFeatures(
    int featureListOffset,
    List<int> featureIndices,
  ) {
    final featureCount = bytes.getUint16(featureListOffset);
    final result = <String, List<int>>{};

    for (final fi in featureIndices) {
      if (fi >= featureCount) continue;

      final recordOffset = featureListOffset + 2 + fi * 6;
      final tag = _readTag(recordOffset);
      final featureOffset =
          featureListOffset + bytes.getUint16(recordOffset + 4);

      // Parse Feature table
      // featureParams at featureOffset + 0 (unused for most features)
      final lookupCount = bytes.getUint16(featureOffset + 2);
      final lookupIndices = <int>[];
      for (var j = 0; j < lookupCount; j++) {
        lookupIndices.add(bytes.getUint16(featureOffset + 4 + j * 2));
      }

      result.putIfAbsent(tag, () => []).addAll(lookupIndices);
    }

    return result;
  }

  /// Parse the LookupList table.
  List<GsubLookup> _parseLookupList(int lookupListOffset) {
    final lookupCount = bytes.getUint16(lookupListOffset);
    final lookups = <GsubLookup>[];

    for (var i = 0; i < lookupCount; i++) {
      final lookupOffset =
          lookupListOffset + bytes.getUint16(lookupListOffset + 2 + i * 2);
      lookups.add(_parseLookup(lookupOffset));
    }

    return lookups;
  }

  /// Parse a single Lookup table.
  GsubLookup _parseLookup(int lookupOffset) {
    var lookupType = bytes.getUint16(lookupOffset);
    // final lookupFlag = bytes.getUint16(lookupOffset + 2);
    final subTableCount = bytes.getUint16(lookupOffset + 4);

    final subtables = <GsubLookup>[];

    for (var i = 0; i < subTableCount; i++) {
      final subtableOffset =
          lookupOffset + bytes.getUint16(lookupOffset + 6 + i * 2);

      // Handle extension lookups (Type 7)
      var actualOffset = subtableOffset;
      var actualType = lookupType;
      if (lookupType == 7) {
        // ExtensionSubstFormat1
        actualType = bytes.getUint16(subtableOffset + 2);
        actualOffset =
            subtableOffset + bytes.getUint32(subtableOffset + 4);
      }

      final parsed = _parseSubtable(actualType, actualOffset);
      if (parsed != null) {
        subtables.add(parsed);
      }
    }

    if (subtables.isEmpty) {
      return const SingleSubstitution({});
    }
    if (subtables.length == 1) {
      return subtables[0];
    }
    return CompositeLookup(subtables);
  }

  /// Parse a lookup subtable based on its type.
  GsubLookup? _parseSubtable(int lookupType, int offset) {
    switch (lookupType) {
      case 1:
        return _parseSingleSubstitution(offset);
      case 4:
        return _parseLigatureSubstitution(offset);
      case 6:
        return _parseChainingContextSubstitution(offset);
      default:
        return null;
    }
  }

  /// Parse a Single Substitution subtable (Type 1).
  GsubLookup _parseSingleSubstitution(int offset) {
    final format = bytes.getUint16(offset);
    final coverageOffset = offset + bytes.getUint16(offset + 2);
    final coverage = CoverageTable.parse(bytes, coverageOffset);

    final substitutions = <int, int>{};

    if (format == 1) {
      // Format 1: deltaGlyphID
      final deltaGlyphId = bytes.getInt16(offset + 4);
      for (final entry in coverage._glyphToIndex.entries) {
        substitutions[entry.key] = (entry.key + deltaGlyphId) & 0xFFFF;
      }
    } else if (format == 2) {
      // Format 2: substituteGlyphIDs array
      final glyphCount = bytes.getUint16(offset + 4);
      for (final entry in coverage._glyphToIndex.entries) {
        if (entry.value < glyphCount) {
          substitutions[entry.key] =
              bytes.getUint16(offset + 6 + entry.value * 2);
        }
      }
    }

    return SingleSubstitution(substitutions);
  }

  /// Parse a Ligature Substitution subtable (Type 4).
  GsubLookup _parseLigatureSubstitution(int offset) {
    final format = bytes.getUint16(offset);
    if (format != 1) return const SingleSubstitution({});

    final coverageOffset = offset + bytes.getUint16(offset + 2);
    final coverage = CoverageTable.parse(bytes, coverageOffset);
    final ligSetCount = bytes.getUint16(offset + 4);

    final ligatureSets = <int, List<LigatureRule>>{};

    for (final entry in coverage._glyphToIndex.entries) {
      final coverageIndex = entry.value;
      if (coverageIndex >= ligSetCount) continue;

      final ligSetOffset =
          offset + bytes.getUint16(offset + 6 + coverageIndex * 2);
      final ligCount = bytes.getUint16(ligSetOffset);
      final rules = <LigatureRule>[];

      for (var j = 0; j < ligCount; j++) {
        final ligOffset =
            ligSetOffset + bytes.getUint16(ligSetOffset + 2 + j * 2);
        final ligGlyph = bytes.getUint16(ligOffset);
        final compCount = bytes.getUint16(ligOffset + 2);
        final components = <int>[];

        for (var k = 0; k < compCount - 1; k++) {
          components.add(bytes.getUint16(ligOffset + 4 + k * 2));
        }

        rules.add(LigatureRule(ligGlyph, components));
      }

      ligatureSets[entry.key] = rules;
    }

    return LigatureSubstitution(ligatureSets);
  }

  /// Parse a Chaining Contextual Substitution subtable (Type 6).
  GsubLookup? _parseChainingContextSubstitution(int offset) {
    final format = bytes.getUint16(offset);

    if (format == 3) {
      return _parseChainingContextFormat3(offset);
    }

    // Formats 1 and 2 are more complex; skip for now
    return null;
  }

  /// Parse Chaining Context Format 3 (coverage-based).
  GsubLookup _parseChainingContextFormat3(int offset) {
    var pos = offset + 2;

    // Backtrack
    final backtrackCount = bytes.getUint16(pos);
    pos += 2;
    final backtrackCoverages = <CoverageTable>[];
    for (var i = 0; i < backtrackCount; i++) {
      final covOffset = offset + bytes.getUint16(pos);
      backtrackCoverages.add(CoverageTable.parse(bytes, covOffset));
      pos += 2;
    }

    // Input
    final inputCount = bytes.getUint16(pos);
    pos += 2;
    final inputCoverages = <CoverageTable>[];
    for (var i = 0; i < inputCount; i++) {
      final covOffset = offset + bytes.getUint16(pos);
      inputCoverages.add(CoverageTable.parse(bytes, covOffset));
      pos += 2;
    }

    // Lookahead
    final lookaheadCount = bytes.getUint16(pos);
    pos += 2;
    final lookaheadCoverages = <CoverageTable>[];
    for (var i = 0; i < lookaheadCount; i++) {
      final covOffset = offset + bytes.getUint16(pos);
      lookaheadCoverages.add(CoverageTable.parse(bytes, covOffset));
      pos += 2;
    }

    // Lookup records
    final lookupRecordCount = bytes.getUint16(pos);
    pos += 2;
    final lookupRecords = <SequenceLookupRecord>[];
    for (var i = 0; i < lookupRecordCount; i++) {
      final seqIdx = bytes.getUint16(pos);
      final lookupIdx = bytes.getUint16(pos + 2);
      lookupRecords.add(SequenceLookupRecord(seqIdx, lookupIdx));
      pos += 4;
    }

    final rule = ChainingContextRule(
      backtrackCoverages: backtrackCoverages,
      inputCoverages: inputCoverages,
      lookaheadCoverages: lookaheadCoverages,
      lookupRecords: lookupRecords,
    );

    return ChainingContextSubstitution([rule]);
  }

  /// Read a 4-byte tag as a string.
  String _readTag(int offset) {
    return String.fromCharCodes([
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
      bytes.getUint8(offset + 3),
    ]);
  }
}
