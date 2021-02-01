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

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'font_metrics.dart';

@immutable
class TtfGlyphInfo {
  const TtfGlyphInfo(this.index, this.data, this.compounds);

  final int index;
  final Uint8List data;
  final List<int> compounds;

  TtfGlyphInfo copy() {
    return TtfGlyphInfo(
      index,
      Uint8List.fromList(data),
      List<int>.from(compounds),
    );
  }

  @override
  String toString() => 'Glyph $index $compounds';
}

class TtfParser {
  TtfParser(ByteData bytes) : bytes = UnmodifiableByteDataView(bytes) {
    final numTables = bytes.getUint16(4);

    for (var i = 0; i < numTables; i++) {
      final name = utf8.decode(bytes.buffer.asUint8List(i * 16 + 12, 4));
      final offset = bytes.getUint32(i * 16 + 20);
      final size = bytes.getUint32(i * 16 + 24);
      tableOffsets[name] = offset;
      tableSize[name] = size;
    }

    assert(tableOffsets.containsKey(head_table),
        'Unable to find the `head` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(name_table),
        'Unable to find the `name` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(hmtx_table),
        'Unable to find the `hmtx` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(hhea_table),
        'Unable to find the `hhea` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(cmap_table),
        'Unable to find the `cmap` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(maxp_table),
        'Unable to find the `maxp` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(loca_table),
        'Unable to find the `loca` table. This file is not a supported TTF font');
    assert(tableOffsets.containsKey(glyf_table),
        'Unable to find the `glyf` table. This file is not a supported TTF font');

    _parseFontName();
    _parseCMap();
    _parseIndexes();
    _parseGlyphs();
  }

  static const String head_table = 'head';
  static const String name_table = 'name';
  static const String hmtx_table = 'hmtx';
  static const String hhea_table = 'hhea';
  static const String cmap_table = 'cmap';
  static const String maxp_table = 'maxp';
  static const String loca_table = 'loca';
  static const String glyf_table = 'glyf';

  final UnmodifiableByteDataView bytes;
  final Map<String, int> tableOffsets = <String, int>{};
  final Map<String, int> tableSize = <String, int>{};
  String? _fontName;
  final Map<int, int> charToGlyphIndexMap = <int, int>{};
  final List<int> glyphOffsets = <int>[];
  final Map<int, PdfFontMetrics> glyphInfoMap = <int, PdfFontMetrics>{};

  int get unitsPerEm => bytes.getUint16(tableOffsets[head_table]! + 18);

  int get xMin => bytes.getInt16(tableOffsets[head_table]! + 36);

  int get yMin => bytes.getInt16(tableOffsets[head_table]! + 38);

  int get xMax => bytes.getInt16(tableOffsets[head_table]! + 40);

  int get yMax => bytes.getInt16(tableOffsets[head_table]! + 42);

  int get indexToLocFormat => bytes.getInt16(tableOffsets[head_table]! + 50);

  int get ascent => bytes.getInt16(tableOffsets[hhea_table]! + 4);

  int get descent => bytes.getInt16(tableOffsets[hhea_table]! + 6);

  int get numOfLongHorMetrics =>
      bytes.getUint16(tableOffsets[hhea_table]! + 34);

  int get numGlyphs => bytes.getUint16(tableOffsets[maxp_table]! + 4);

  String? get fontName => _fontName;

  bool get unicode => bytes.getUint32(0) == 0x10000;

  // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6name.html
  void _parseFontName() {
    final basePosition = tableOffsets[name_table]!;
    final count = bytes.getUint16(basePosition + 2);
    final stringOffset = bytes.getUint16(basePosition + 4);
    var pos = basePosition + 6;
    for (var i = 0; i < count; i++) {
      final platformID = bytes.getUint16(pos);
      final nameID = bytes.getUint16(pos + 6);
      final length = bytes.getUint16(pos + 8);
      final offset = bytes.getUint16(pos + 10);
      pos += 12;
      if (platformID == 1 && nameID == 6) {
        try {
          _fontName = utf8.decode(bytes.buffer
              .asUint8List(basePosition + stringOffset + offset, length));
          return;
        } catch (a) {
          print('Error: $platformID $nameID $a');
        }
      }
      if (platformID == 3 && nameID == 6) {
        try {
          _fontName = _decodeUtf16(bytes.buffer
              .asUint8List(basePosition + stringOffset + offset, length));
          return;
        } catch (a) {
          print('Error: $platformID $nameID $a');
        }
      }
    }
    _fontName = hashCode.toString();
  }

  void _parseCMap() {
    final basePosition = tableOffsets[cmap_table]!;
    final numSubTables = bytes.getUint16(basePosition + 2);
    for (var i = 0; i < numSubTables; i++) {
      final offset = bytes.getUint32(basePosition + i * 8 + 8);
      final format = bytes.getUint16(basePosition + offset);

      switch (format) {
        case 0:
          _parseCMapFormat0(basePosition + offset + 2);
          break;

        case 4:
          _parseCMapFormat4(basePosition + offset + 2);
          break;
        case 6:
          _parseCMapFormat6(basePosition + offset + 2);
          break;

        case 12:
          _parseCMapFormat12(basePosition + offset + 2);
          break;
      }
    }
  }

  void _parseCMapFormat0(int basePosition) {
    assert(bytes.getUint16(basePosition) == 262);
    for (var i = 0; i < 256; i++) {
      final charCode = i;
      final glyphIndex = bytes.getUint8(basePosition + i + 2);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat4(int basePosition) {
    final segCount = bytes.getUint16(basePosition + 4) ~/ 2;
    final endCodes = <int>[];
    for (var i = 0; i < segCount; i++) {
      endCodes.add(bytes.getUint16(basePosition + i * 2 + 12));
    }
    final startCodes = <int>[];
    for (var i = 0; i < segCount; i++) {
      startCodes.add(bytes.getUint16(basePosition + (segCount + i) * 2 + 14));
    }
    final idDeltas = <int>[];
    for (var i = 0; i < segCount; i++) {
      idDeltas.add(bytes.getUint16(basePosition + (segCount * 2 + i) * 2 + 14));
    }
    final idRangeOffsetBasePos = basePosition + segCount * 6 + 14;
    final idRangeOffsets = <int>[];
    for (var i = 0; i < segCount; i++) {
      idRangeOffsets.add(bytes.getUint16(idRangeOffsetBasePos + i * 2));
    }
    for (var s = 0; s < segCount - 1; s++) {
      final startCode = startCodes[s];
      final endCode = endCodes[s];
      final idDelta = idDeltas[s];
      final idRangeOffset = idRangeOffsets[s];
      final idRangeOffsetAddress = idRangeOffsetBasePos + s * 2;
      for (var c = startCode; c <= endCode; c++) {
        int glyphIndex;
        if (idRangeOffset == 0) {
          glyphIndex = (idDelta + c) % 65536;
        } else {
          final glyphIndexAddress =
              idRangeOffset + 2 * (c - startCode) + idRangeOffsetAddress;
          glyphIndex = bytes.getUint16(glyphIndexAddress);
        }
        charToGlyphIndexMap[c] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat6(int basePosition) {
    final firstCode = bytes.getUint16(basePosition + 4);
    final entryCount = bytes.getUint16(basePosition + 6);
    for (var i = 0; i < entryCount; i++) {
      final charCode = firstCode + i;
      final glyphIndex = bytes.getUint16(basePosition + i * 2 + 8);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat12(int basePosition) {
    final numGroups = bytes.getUint32(basePosition + 10);
    assert(bytes.getUint32(basePosition + 2) == 12 * numGroups + 16);

    for (var i = 0; i < numGroups; i++) {
      final startCharCode = bytes.getUint32(basePosition + i * 12 + 14);
      final endCharCode = bytes.getUint32(basePosition + i * 12 + 18);
      final startGlyphID = bytes.getUint32(basePosition + i * 12 + 22);

      for (var j = startCharCode; j <= endCharCode; j++) {
        assert(!charToGlyphIndexMap.containsKey(j) ||
            charToGlyphIndexMap[j] == startGlyphID + j - startCharCode);
        charToGlyphIndexMap[j] = startGlyphID + j - startCharCode;
      }
    }
  }

  void _parseIndexes() {
    final basePosition = tableOffsets[loca_table];
    final numGlyphs = this.numGlyphs;
    if (indexToLocFormat == 0) {
      for (var i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint16(basePosition! + i * 2) * 2);
      }
    } else {
      for (var i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint32(basePosition! + i * 4));
      }
    }
  }

  /// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6glyf.html
  void _parseGlyphs() {
    final baseOffset = tableOffsets[glyf_table];
    final hmtxOffset = tableOffsets[hmtx_table]!;
    final unitsPerEm = this.unitsPerEm;
    final numOfLongHorMetrics = this.numOfLongHorMetrics;
    final defaultadvanceWidth =
        bytes.getUint16(hmtxOffset + (numOfLongHorMetrics - 1) * 4);
    var glyphIndex = 0;
    for (var offset in glyphOffsets) {
      final xMin = bytes.getInt16(baseOffset! + offset + 2); // 2
      final yMin = bytes.getInt16(baseOffset + offset + 4); // 4
      final xMax = bytes.getInt16(baseOffset + offset + 6); // 6
      final yMax = bytes.getInt16(baseOffset + offset + 8); // 8
      final advanceWidth = glyphIndex < numOfLongHorMetrics
          ? bytes.getUint16(hmtxOffset + glyphIndex * 4)
          : defaultadvanceWidth;
      final leftBearing = glyphIndex < numOfLongHorMetrics
          ? bytes.getInt16(hmtxOffset + glyphIndex * 4 + 2)
          : bytes.getInt16(hmtxOffset +
              numOfLongHorMetrics * 4 +
              (glyphIndex - numOfLongHorMetrics) * 2);
      glyphInfoMap[glyphIndex] = PdfFontMetrics(
        left: xMin.toDouble() / unitsPerEm,
        top: yMin.toDouble() / unitsPerEm,
        right: xMax.toDouble() / unitsPerEm,
        bottom: yMax.toDouble() / unitsPerEm,
        ascent: ascent.toDouble() / unitsPerEm,
        descent: descent.toDouble() / unitsPerEm,
        advanceWidth: advanceWidth.toDouble() / unitsPerEm,
        leftBearing: leftBearing.toDouble() / unitsPerEm,
      );
      glyphIndex++;
    }
  }

  /// http://stevehanov.ca/blog/?id=143
  TtfGlyphInfo readGlyph(int index) {
    assert(index < glyphOffsets.length);

    final start = tableOffsets[glyf_table]! + glyphOffsets[index];

    final numberOfContours = bytes.getInt16(start);
    assert(numberOfContours >= -1);

    if (numberOfContours == -1) {
      return _readCompoundGlyph(index, start, start + 10);
    } else {
      return _readSimpleGlyph(index, start, start + 10, numberOfContours);
    }
  }

  TtfGlyphInfo _readSimpleGlyph(
      int glyph, int start, int offset, int numberOfContours) {
    const X_IS_BYTE = 2;
    const Y_IS_BYTE = 4;
    const REPEAT = 8;
    const X_DELTA = 16;
    const Y_DELTA = 32;

    var numPoints = 1;

    for (var i = 0; i < numberOfContours; i++) {
      numPoints = math.max(numPoints, bytes.getUint16(offset) + 1);
      offset += 2;
    }

    // skip over intructions
    offset += bytes.getUint16(offset) + 2;

    if (numberOfContours == 0) {
      return TtfGlyphInfo(
        glyph,
        Uint8List.view(bytes.buffer, start, offset - start),
        const <int>[],
      );
    }

    final flags = <int>[];

    for (var i = 0; i < numPoints; i++) {
      final flag = bytes.getUint8(offset++);
      flags.add(flag);

      if (flag & REPEAT != 0) {
        var repeatCount = bytes.getUint8(offset++);
        assert(repeatCount > 0);
        i += repeatCount;
        while (repeatCount-- > 0) {
          flags.add(flag);
        }
      }
    }

    var byteFlag = X_IS_BYTE;
    var deltaFlag = X_DELTA;
    for (var a = 0; a < 2; a++) {
      for (var i = 0; i < numPoints; i++) {
        final flag = flags[i];
        if (flag & byteFlag != 0) {
          offset++;
        } else if (~flag & deltaFlag != 0) {
          offset += 2;
        }
      }
      byteFlag = Y_IS_BYTE;
      deltaFlag = Y_DELTA;
    }

    return TtfGlyphInfo(
      glyph,
      Uint8List.view(bytes.buffer, start, offset - start),
      const <int>[],
    );
  }

  TtfGlyphInfo _readCompoundGlyph(int glyph, int start, int offset) {
    const ARG_1_AND_2_ARE_WORDS = 1;
    const MORE_COMPONENTS = 32;
    const WE_HAVE_INSTRUCTIONS = 256;

    final components = <int>[];
    var hasInstructions = false;
    var flags = MORE_COMPONENTS;

    while (flags & MORE_COMPONENTS != 0) {
      flags = bytes.getUint16(offset);
      final glyphIndex = bytes.getUint16(offset + 2);
      offset += (flags & ARG_1_AND_2_ARE_WORDS != 0) ? 8 : 6;

      components.add(glyphIndex);
      if (flags & WE_HAVE_INSTRUCTIONS != 0) {
        assert(!hasInstructions); // Not already set
        hasInstructions = true;
      }
    }

    if (hasInstructions) {
      offset += bytes.getUint16(offset) + 2;
    }

    return TtfGlyphInfo(
      glyph,
      Uint8List.view(bytes.buffer, start, offset - start),
      components,
    );
  }

  String _decodeUtf16(Uint8List bytes) {
    final charCodes = <int>[];
    for (var i = 0; i < bytes.length; i += 2) {
      charCodes.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(charCodes);
  }
}
