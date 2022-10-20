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

enum TtfParserName {
  copyright,
  fontFamily,
  fontSubfamily,
  uniqueID,
  fullName,
  version,
  postScriptName,
  trademark,
  manufacturer,
  designer,
  description,
  manufacturerURL,
  designerURL,
  license,
  licenseURL,
  reserved,
  preferredFamily,
  preferredSubfamily,
  compatibleFullName,
  sampleText,
  postScriptFindFontName,
  wwsFamily,
  wwsSubfamily,
}

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

class TtfBitmapInfo {
  const TtfBitmapInfo(
    this.data,
    this.height,
    this.width,
    this.horiBearingX,
    this.horiBearingY,
    this.horiAdvance,
    this.vertBearingX,
    this.vertBearingY,
    this.vertAdvance,
    this.ascent,
    this.descent,
  );

  final Uint8List data;
  final int height;
  final int width;
  final int horiBearingX;
  final int horiBearingY;
  final int horiAdvance;
  final int vertBearingX;
  final int vertBearingY;
  final int vertAdvance;
  final int ascent;
  final int descent;

  PdfFontMetrics get metrics {
    final coef = 1.0 / height;
    return PdfFontMetrics(
      bottom: horiBearingY * coef,
      left: horiBearingX * coef,
      top: horiBearingY * coef - height * coef,
      right: horiAdvance * coef,
      ascent: ascent * coef,
      descent: horiBearingY * coef,
      advanceWidth: horiAdvance * coef,
      leftBearing: horiBearingX * coef,
    );
  }

  @override
  String toString() =>
      'Bitmap Glyph ${width}x$height horiBearingX:$horiBearingX horiBearingY:$horiBearingY horiAdvance:$horiAdvance ascender:$ascent descender:$descent';
}

class TtfParser {
   TtfParser(ByteData bytes) {
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

    _parseCMap();
    if (tableOffsets.containsKey(loca_table) &&
        tableOffsets.containsKey(glyf_table)) {
      _parseIndexes();
      _parseGlyphs();
    }
    if (tableOffsets.containsKey(cblc_table) &&
        tableOffsets.containsKey(cbdt_table)) {
      _parseBitmaps();
    }
  }

  static const String head_table = 'head';
  static const String name_table = 'name';
  static const String hmtx_table = 'hmtx';
  static const String hhea_table = 'hhea';
  static const String cmap_table = 'cmap';
  static const String maxp_table = 'maxp';
  static const String loca_table = 'loca';
  static const String glyf_table = 'glyf';
  static const String cblc_table = 'CBLC';
  static const String cbdt_table = 'CBDT';

  final UnmodifiableByteDataView bytes;
  final tableOffsets = <String, int>{};
  final tableSize = <String, int>{};

  final charToGlyphIndexMap = <int, int>{};
  final glyphOffsets = <int>[];
  final glyphSizes = <int>[];
  final glyphInfoMap = <int, PdfFontMetrics>{};
  final bitmapOffsets = <int, TtfBitmapInfo>{};

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

  String get fontName =>
      getNameID(TtfParserName.postScriptName) ?? hashCode.toString();

  bool get unicode => bytes.getUint32(0) == 0x10000;

  bool get isBitmap => bitmapOffsets.isNotEmpty && glyphOffsets.isEmpty;

  // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6name.html
  String? getNameID(TtfParserName fontNameID) {
    final basePosition = tableOffsets[name_table];
    if (basePosition == null) {
      return null;
    }
    // final format = bytes.getUint16(basePosition);
    final count = bytes.getUint16(basePosition + 2);
    final stringOffset = bytes.getUint16(basePosition + 4);
    var pos = basePosition + 6;
    String? _fontName;

    for (var i = 0; i < count; i++) {
      final platformID = bytes.getUint16(pos);
      final nameID = bytes.getUint16(pos + 6);
      final length = bytes.getUint16(pos + 8);
      final offset = bytes.getUint16(pos + 10);
      pos += 12;

      if (platformID == 1 && nameID == fontNameID.index) {
        try {
          _fontName = utf8.decode(bytes.buffer
              .asUint8List(basePosition + stringOffset + offset, length));
        } catch (a) {
          print('Error: $platformID $nameID $a');
        }
      }

      if (platformID == 3 && nameID == fontNameID.index) {
        try {
          return _decodeUtf16(bytes.buffer
              .asUint8List(basePosition + stringOffset + offset, length));
        } catch (a) {
          print('Error: $platformID $nameID $a');
        }
      }
    }
    return _fontName;
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
    final basePosition = tableOffsets[loca_table]!;
    if (indexToLocFormat == 0) {
      var prevOffset = bytes.getUint16(basePosition) * 2;
      for (var i = 1; i < numGlyphs + 1; i++) {
        final offset = bytes.getUint16(basePosition + i * 2) * 2;
        glyphOffsets.add(prevOffset);
        glyphSizes.add(offset - prevOffset);
        prevOffset = offset;
      }
    } else {
      var prevOffset = bytes.getUint32(basePosition);
      for (var i = 1; i < numGlyphs + 1; i++) {
        final offset = bytes.getUint32(basePosition + i * 4);
        glyphOffsets.add(prevOffset);
        glyphSizes.add(offset - prevOffset);
        prevOffset = offset;
      }
    }
  }

  /// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6glyf.html
  void _parseGlyphs() {
    final baseOffset = tableOffsets[glyf_table]!;
    final hmtxOffset = tableOffsets[hmtx_table]!;
    final unitsPerEm = this.unitsPerEm;
    final numOfLongHorMetrics = this.numOfLongHorMetrics;
    final defaultadvanceWidth =
        bytes.getUint16(hmtxOffset + (numOfLongHorMetrics - 1) * 4);

    for (var glyphIndex = 0; glyphIndex < numGlyphs; glyphIndex++) {
      final advanceWidth = glyphIndex < numOfLongHorMetrics
          ? bytes.getUint16(hmtxOffset + glyphIndex * 4)
          : defaultadvanceWidth;
      final leftBearing = glyphIndex < numOfLongHorMetrics
          ? bytes.getInt16(hmtxOffset + glyphIndex * 4 + 2)
          : bytes.getInt16(hmtxOffset +
              numOfLongHorMetrics * 4 +
              (glyphIndex - numOfLongHorMetrics) * 2);
      if (glyphSizes[glyphIndex] == 0) {
        glyphInfoMap[glyphIndex] = PdfFontMetrics(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          ascent: 0,
          descent: 0,
          advanceWidth: advanceWidth / unitsPerEm,
          leftBearing: leftBearing / unitsPerEm,
        );
        continue;
      }
      final offset = glyphOffsets[glyphIndex];
      final xMin = bytes.getInt16(baseOffset + offset + 2); // 2
      final yMin = bytes.getInt16(baseOffset + offset + 4); // 4
      final xMax = bytes.getInt16(baseOffset + offset + 6); // 6
      final yMax = bytes.getInt16(baseOffset + offset + 8); // 8

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
    const ARG_1_AND_2_ARE_WORDS = 0x0001;
    const HAS_SCALE = 0x008;
    const MORE_COMPONENTS = 0x0020;
    const HAS_X_Y_SCALE = 0x0040;
    const HAS_TRANFORMATION_MATRIX = 0x0080;
    const WE_HAVE_INSTRUCTIONS = 0x0100;

    final components = <int>[];
    var hasInstructions = false;
    var flags = MORE_COMPONENTS;

    while (flags & MORE_COMPONENTS != 0) {
      flags = bytes.getUint16(offset);
      final glyphIndex = bytes.getUint16(offset + 2);
      offset += (flags & ARG_1_AND_2_ARE_WORDS != 0) ? 8 : 6;
      if (flags & HAS_SCALE != 0) {
        offset += 2;
      } else if (flags & HAS_X_Y_SCALE != 0) {
        offset += 4;
      } else if (flags & HAS_TRANFORMATION_MATRIX != 0) {
        offset += 8;
      }

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

  // https://docs.microsoft.com/en-us/typography/opentype/spec/ebdt
  void _parseBitmaps() {
    final baseOffset = tableOffsets[cblc_table]!;
    final pngOffset = tableOffsets[cbdt_table]!;

    // CBLC Header
    final numSizes = bytes.getUint32(baseOffset + 4);
    var bitmapSize = baseOffset + 8;

    for (var bitmapSizeIndex = 0;
        bitmapSizeIndex < numSizes;
        bitmapSizeIndex++) {
      // BitmapSize Record
      final indexSubTableArrayOffset = baseOffset + bytes.getUint32(bitmapSize);
      // final indexTablesSize = bytes.getUint32(bitmapSize + 4);
      final numberOfIndexSubTables = bytes.getUint32(bitmapSize + 8);

      final ascender = bytes.getInt8(bitmapSize + 12);
      final descender = bytes.getInt8(bitmapSize + 13);

      // final startGlyphIndex = bytes.getUint16(bitmapSize + 16 + 12 * 2);
      // final endGlyphIndex = bytes.getUint16(bitmapSize + 16 + 12 * 2 + 2);
      // final ppemX = bytes.getUint8(bitmapSize + 16 + 12 * 2 + 4);
      // final ppemY = bytes.getUint8(bitmapSize + 16 + 12 * 2 + 5);
      // final bitDepth = bytes.getUint8(bitmapSize + 16 + 12 * 2 + 6);
      // final flags = bytes.getUint8(bitmapSize + 16 + 12 * 2 + 7);

      var subTableArrayOffset = indexSubTableArrayOffset;
      for (var indexSubTable = 0;
          indexSubTable < numberOfIndexSubTables;
          indexSubTable++) {
        // IndexSubTableArray
        final firstGlyphIndex = bytes.getUint16(subTableArrayOffset);
        final lastGlyphIndex = bytes.getUint16(subTableArrayOffset + 2);
        final additionalOffsetToIndexSubtable =
            indexSubTableArrayOffset + bytes.getUint32(subTableArrayOffset + 4);

        // IndexSubHeader
        final indexFormat = bytes.getUint16(additionalOffsetToIndexSubtable);
        final imageFormat =
            bytes.getUint16(additionalOffsetToIndexSubtable + 2);
        final imageDataOffset =
            pngOffset + bytes.getUint32(additionalOffsetToIndexSubtable + 4);

        if (indexFormat == 1) {
          // IndexSubTable1

          for (var glyph = firstGlyphIndex; glyph <= lastGlyphIndex; glyph++) {
            final sbitOffset = imageDataOffset +
                bytes.getUint32(additionalOffsetToIndexSubtable +
                    (glyph - firstGlyphIndex + 2) * 4);

            if (imageFormat == 17) {
              final height = bytes.getUint8(sbitOffset);
              final width = bytes.getUint8(sbitOffset + 1);
              final bearingX = bytes.getInt8(sbitOffset + 2);
              final bearingY = bytes.getInt8(sbitOffset + 3);
              final advance = bytes.getUint8(sbitOffset + 4);
              final dataLen = bytes.getUint32(sbitOffset + 5);

              bitmapOffsets[glyph] = TtfBitmapInfo(
                  bytes.buffer.asUint8List(
                    bytes.offsetInBytes + sbitOffset + 9,
                    dataLen,
                  ),
                  height,
                  width,
                  bearingX,
                  bearingY,
                  advance,
                  0,
                  0,
                  0,
                  ascender,
                  descender);
            }
          }
        }

        subTableArrayOffset += 8;
      }
      bitmapSize += 16 + 12 * 2 + 8;
    }
  }

  TtfBitmapInfo? getBitmap(int charcode) =>
      bitmapOffsets[charToGlyphIndexMap[charcode]];
}
