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

import 'gsub_parser.dart';

/// Value record for GPOS positioning adjustments.
class ValueRecord {
  const ValueRecord({
    this.xPlacement = 0,
    this.yPlacement = 0,
    this.xAdvance = 0,
    this.yAdvance = 0,
  });

  /// Horizontal placement adjustment (in font units)
  final int xPlacement;

  /// Vertical placement adjustment (in font units)
  final int yPlacement;

  /// Horizontal advance adjustment (in font units)
  final int xAdvance;

  /// Vertical advance adjustment (in font units)
  final int yAdvance;

  static const zero = ValueRecord();

  bool get isZero =>
      xPlacement == 0 &&
      yPlacement == 0 &&
      xAdvance == 0 &&
      yAdvance == 0;
}

/// Per-glyph positioning result.
class GlyphPosition {
  const GlyphPosition({
    this.xPlacement = 0,
    this.yPlacement = 0,
    this.xAdvanceAdjust = 0,
    this.yAdvanceAdjust = 0,
  });

  /// Horizontal placement offset (in font units)
  final int xPlacement;

  /// Vertical placement offset (in font units)
  final int yPlacement;

  /// Horizontal advance adjustment (in font units)
  final int xAdvanceAdjust;

  /// Vertical advance adjustment (in font units)
  final int yAdvanceAdjust;

  static const zero = GlyphPosition();

  bool get isZero =>
      xPlacement == 0 &&
      yPlacement == 0 &&
      xAdvanceAdjust == 0 &&
      yAdvanceAdjust == 0;
}

/// Anchor point for mark-to-base attachment.
class _AnchorPoint {
  const _AnchorPoint(this.x, this.y);

  final int x;
  final int y;
}

/// Parsed GPOS data for a font.
class GposData {
  GposData(this._pairKerning, this._markToBase);

  /// Pair kerning: first glyph → (second glyph → value records)
  final Map<int, Map<int, ValueRecord>> _pairKerning;

  /// Mark-to-base: mark glyph → (base glyph → position offset)
  final Map<int, _MarkToBaseEntry> _markToBase;

  /// Apply GPOS positioning to a glyph sequence.
  /// Returns a list of positioning adjustments, one per glyph.
  List<GlyphPosition> position(List<int> glyphIds) {
    final positions = List<GlyphPosition>.filled(
      glyphIds.length,
      GlyphPosition.zero,
    );

    for (var i = 0; i < glyphIds.length; i++) {
      final glyph = glyphIds[i];

      // Apply pair kerning
      if (i + 1 < glyphIds.length) {
        final secondGlyph = glyphIds[i + 1];
        final pairs = _pairKerning[glyph];
        if (pairs != null) {
          final value = pairs[secondGlyph];
          if (value != null) {
            positions[i] = GlyphPosition(
              xPlacement: positions[i].xPlacement + value.xPlacement,
              yPlacement: positions[i].yPlacement + value.yPlacement,
              xAdvanceAdjust: positions[i].xAdvanceAdjust + value.xAdvance,
              yAdvanceAdjust: positions[i].yAdvanceAdjust + value.yAdvance,
            );
          }
        }
      }

      // Apply mark-to-base positioning
      final markEntry = _markToBase[glyph];
      if (markEntry != null && i > 0) {
        // Find the base glyph (look backwards, skip other marks)
        for (var j = i - 1; j >= 0; j--) {
          final baseGlyph = glyphIds[j];
          final baseAnchor = markEntry.baseAnchors[baseGlyph];
          if (baseAnchor != null) {
            // Position the mark relative to the base anchor
            positions[i] = GlyphPosition(
              xPlacement: baseAnchor.x - markEntry.markAnchor.x,
              yPlacement: baseAnchor.y - markEntry.markAnchor.y,
              xAdvanceAdjust: 0,
              yAdvanceAdjust: 0,
            );
            break;
          }
        }
      }
    }

    return positions;
  }

  /// Whether any positioning data exists
  bool get hasData => _pairKerning.isNotEmpty || _markToBase.isNotEmpty;
}

/// Mark-to-base attachment data for a single mark glyph.
class _MarkToBaseEntry {
  const _MarkToBaseEntry(this.markAnchor, this.baseAnchors);

  final _AnchorPoint markAnchor;
  final Map<int, _AnchorPoint> baseAnchors;
}

/// Parse the OpenType GPOS table from font bytes.
class GposParser {
  GposParser(this.bytes);

  final ByteData bytes;

  /// Parse the GPOS table starting at [tableOffset].
  GposData? parse(int tableOffset, List<String> scriptTags) {
    if (tableOffset == 0) return null;

    try {
      final majorVersion = bytes.getUint16(tableOffset);
      if (majorVersion != 1) return null;

      final scriptListOffset =
          tableOffset + bytes.getUint16(tableOffset + 4);
      final featureListOffset =
          tableOffset + bytes.getUint16(tableOffset + 6);
      final lookupListOffset =
          tableOffset + bytes.getUint16(tableOffset + 8);

      // Find matching script
      final featureIndices =
          _findScriptFeatures(scriptListOffset, scriptTags);
      if (featureIndices == null) return null;

      // Parse feature list
      final lookupIndices =
          _parseFeaturesFlat(featureListOffset, featureIndices);
      if (lookupIndices.isEmpty) return null;

      // Parse relevant lookups
      final pairKerning = <int, Map<int, ValueRecord>>{};
      final markToBase = <int, _MarkToBaseEntry>{};

      final lookupCount = bytes.getUint16(lookupListOffset);

      for (final idx in lookupIndices) {
        if (idx >= lookupCount) continue;

        final lookupOffset = lookupListOffset +
            bytes.getUint16(lookupListOffset + 2 + idx * 2);

        var lookupType = bytes.getUint16(lookupOffset);
        final subTableCount = bytes.getUint16(lookupOffset + 4);

        for (var i = 0; i < subTableCount; i++) {
          var subtableOffset =
              lookupOffset + bytes.getUint16(lookupOffset + 6 + i * 2);
          var actualType = lookupType;

          // Handle extension (Type 9)
          if (lookupType == 9) {
            actualType = bytes.getUint16(subtableOffset + 2);
            subtableOffset =
                subtableOffset + bytes.getUint32(subtableOffset + 4);
          }

          switch (actualType) {
            case 2: // Pair Adjustment
              _parsePairAdjustment(subtableOffset, pairKerning);
              break;
            case 4: // Mark-to-Base Attachment
              _parseMarkToBase(subtableOffset, markToBase);
              break;
          }
        }
      }

      final data = GposData(pairKerning, markToBase);
      return data.hasData ? data : null;
    } catch (e) {
      assert(() {
        print('GPOS parsing failed: $e');
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

    // Fallback: try DFLT script
    for (var i = 0; i < scriptCount; i++) {
      final recordOffset = scriptListOffset + 2 + i * 6;
      final tag = _readTag(recordOffset);

      if (tag == 'DFLT') {
        final scriptOffset =
            scriptListOffset + bytes.getUint16(recordOffset + 4);
        return _parseScript(scriptOffset);
      }
    }

    return null;
  }

  List<int> _parseScript(int scriptOffset) {
    final defaultLangSysOffset = bytes.getUint16(scriptOffset);
    if (defaultLangSysOffset == 0) {
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

  /// Parse features and return a flat list of lookup indices.
  List<int> _parseFeaturesFlat(
    int featureListOffset,
    List<int> featureIndices,
  ) {
    final featureCount = bytes.getUint16(featureListOffset);
    final lookupIndices = <int>{};

    // Target GPOS features relevant for our scripts
    const targetFeatures = {
      'kern', // Kerning
      'mark', // Mark positioning (mark-to-base)
      'mkmk', // Mark-to-mark positioning
      'dist', // Distance adjustments (Indic)
      'abvm', // Above-base mark positioning
      'blwm', // Below-base mark positioning
    };

    for (final fi in featureIndices) {
      if (fi >= featureCount) continue;

      final recordOffset = featureListOffset + 2 + fi * 6;
      final tag = _readTag(recordOffset);

      if (!targetFeatures.contains(tag)) continue;

      final featureOffset =
          featureListOffset + bytes.getUint16(recordOffset + 4);
      final lookupCount = bytes.getUint16(featureOffset + 2);
      for (var j = 0; j < lookupCount; j++) {
        lookupIndices.add(bytes.getUint16(featureOffset + 4 + j * 2));
      }
    }

    return lookupIndices.toList()..sort();
  }

  /// Parse Pair Adjustment subtable (Type 2).
  void _parsePairAdjustment(
    int offset,
    Map<int, Map<int, ValueRecord>> result,
  ) {
    final format = bytes.getUint16(offset);

    if (format == 1) {
      _parsePairAdjustmentFormat1(offset, result);
    } else if (format == 2) {
      _parsePairAdjustmentFormat2(offset, result);
    }
  }

  /// Parse Pair Adjustment Format 1 (individual pairs).
  void _parsePairAdjustmentFormat1(
    int offset,
    Map<int, Map<int, ValueRecord>> result,
  ) {
    final coverageOffset = offset + bytes.getUint16(offset + 2);
    final coverage = CoverageTable.parse(bytes, coverageOffset);
    final valueFormat1 = bytes.getUint16(offset + 4);
    final valueFormat2 = bytes.getUint16(offset + 6);
    final pairSetCount = bytes.getUint16(offset + 8);

    final vr1Size = _valueRecordSize(valueFormat1);
    final vr2Size = _valueRecordSize(valueFormat2);

    for (final entry in coverage.entries) {
      final firstGlyph = entry.key;
      final coverageIndex = entry.value;
      if (coverageIndex >= pairSetCount) continue;

      final pairSetOffset =
          offset + bytes.getUint16(offset + 10 + coverageIndex * 2);
      final pairValueCount = bytes.getUint16(pairSetOffset);

      for (var j = 0; j < pairValueCount; j++) {
        final pairOffset = pairSetOffset + 2 + j * (2 + vr1Size + vr2Size);
        final secondGlyph = bytes.getUint16(pairOffset);
        final value1 = _readValueRecord(pairOffset + 2, valueFormat1);

        if (!value1.isZero) {
          result
              .putIfAbsent(firstGlyph, () => <int, ValueRecord>{})
              [secondGlyph] = value1;
        }
      }
    }
  }

  /// Parse Pair Adjustment Format 2 (class-based).
  /// Class-based kerning is complex to expand into per-glyph pairs.
  /// We skip it for now — Format 1 (individual pairs) handles most
  /// kerning in Indic fonts.
  void _parsePairAdjustmentFormat2(
    int offset,
    Map<int, Map<int, ValueRecord>> result,
  ) {
    // Class-based pair adjustment is very expensive to expand into
    // per-glyph data and is less common in Indic fonts.
    // Skip for now — Format 1 handles individual pairs.
  }

  /// Parse Mark-to-Base Attachment subtable (Type 4).
  void _parseMarkToBase(
    int offset,
    Map<int, _MarkToBaseEntry> result,
  ) {
    final format = bytes.getUint16(offset);
    if (format != 1) return;

    final markCoverageOffset = offset + bytes.getUint16(offset + 2);
    final baseCoverageOffset = offset + bytes.getUint16(offset + 4);
    final classCount = bytes.getUint16(offset + 6);
    final markArrayOffset = offset + bytes.getUint16(offset + 8);
    final baseArrayOffset = offset + bytes.getUint16(offset + 10);

    final markCoverage = CoverageTable.parse(bytes, markCoverageOffset);
    final baseCoverage = CoverageTable.parse(bytes, baseCoverageOffset);

    // Parse mark array
    final markCount = bytes.getUint16(markArrayOffset);

    // Parse base array
    final baseCount = bytes.getUint16(baseArrayOffset);

    for (final markEntry in markCoverage.entries) {
      final markGlyph = markEntry.key;
      final markIndex = markEntry.value;
      if (markIndex >= markCount) continue;

      final recordOffset = markArrayOffset + 2 + markIndex * 4;
      final markClass = bytes.getUint16(recordOffset);
      if (markClass >= classCount) continue;

      final markAnchorOffset =
          markArrayOffset + bytes.getUint16(recordOffset + 2);
      final markAnchor = _readAnchor(markAnchorOffset);

      final baseAnchorsMap = <int, _AnchorPoint>{};

      for (final baseEntry in baseCoverage.entries) {
        final baseGlyph = baseEntry.key;
        final baseIndex = baseEntry.value;
        if (baseIndex >= baseCount) continue;

        final baseRecordOffset =
            baseArrayOffset + 2 + baseIndex * classCount * 2;
        final anchorOffset = bytes.getUint16(
          baseRecordOffset + markClass * 2,
        );

        if (anchorOffset != 0) {
          final anchor = _readAnchor(baseArrayOffset + anchorOffset);
          baseAnchorsMap[baseGlyph] = anchor;
        }
      }

      if (baseAnchorsMap.isNotEmpty) {
        result[markGlyph] = _MarkToBaseEntry(markAnchor, baseAnchorsMap);
      }
    }
  }

  /// Read an anchor point at the given offset.
  _AnchorPoint _readAnchor(int offset) {
    // Format 1, 2, or 3 — all start with format, x, y
    final x = bytes.getInt16(offset + 2);
    final y = bytes.getInt16(offset + 4);
    return _AnchorPoint(x, y);
  }

  /// Read a ValueRecord at the given offset with the specified format.
  ValueRecord _readValueRecord(int offset, int valueFormat) {
    var pos = offset;
    int xPlacement = 0, yPlacement = 0, xAdvance = 0, yAdvance = 0;

    if (valueFormat & 0x0001 != 0) {
      xPlacement = bytes.getInt16(pos);
      pos += 2;
    }
    if (valueFormat & 0x0002 != 0) {
      yPlacement = bytes.getInt16(pos);
      pos += 2;
    }
    if (valueFormat & 0x0004 != 0) {
      xAdvance = bytes.getInt16(pos);
      pos += 2;
    }
    if (valueFormat & 0x0008 != 0) {
      yAdvance = bytes.getInt16(pos);
      pos += 2;
    }
    // Skip device table offsets (bits 4-7)

    return ValueRecord(
      xPlacement: xPlacement,
      yPlacement: yPlacement,
      xAdvance: xAdvance,
      yAdvance: yAdvance,
    );
  }

  /// Calculate the size in bytes of a ValueRecord.
  int _valueRecordSize(int valueFormat) {
    var size = 0;
    for (var i = 0; i < 8; i++) {
      if (valueFormat & (1 << i) != 0) size += 2;
    }
    return size;
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
