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

// ignore_for_file: omit_local_variable_types

part of pdf;

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
    final int numTables = bytes.getUint16(4);

    for (int i = 0; i < numTables; i++) {
      final String name = utf8.decode(bytes.buffer.asUint8List(i * 16 + 12, 4));
      final int offset = bytes.getUint32(i * 16 + 20);
      final int size = bytes.getUint32(i * 16 + 24);
      tableOffsets[name] = offset;
      tableSize[name] = size;
    }

    _parseFontName();
    _parseCMap();
    _parseIndexes();
    _parseGlyphs();
    if (tableOffsets.containsKey(gsub_table)) {
      _parseGsub();
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
  static const String gsub_table = 'GSUB';

  final UnmodifiableByteDataView bytes;
  final Map<String, int> tableOffsets = <String, int>{};
  final Map<String, int> tableSize = <String, int>{};
  String _fontName;
  final Map<int, int> charToGlyphIndexMap = <int, int>{};
  final List<int> glyphOffsets = <int>[];
  final Map<int, PdfFontMetrics> glyphInfoMap = <int, PdfFontMetrics>{};

  int get unitsPerEm => bytes.getUint16(tableOffsets[head_table] + 18);

  int get xMin => bytes.getInt16(tableOffsets[head_table] + 36);

  int get yMin => bytes.getInt16(tableOffsets[head_table] + 38);

  int get xMax => bytes.getInt16(tableOffsets[head_table] + 40);

  int get yMax => bytes.getInt16(tableOffsets[head_table] + 42);

  int get indexToLocFormat => bytes.getInt16(tableOffsets[head_table] + 50);

  int get ascent => bytes.getInt16(tableOffsets[hhea_table] + 4);

  int get descent => bytes.getInt16(tableOffsets[hhea_table] + 6);

  int get numOfLongHorMetrics => bytes.getUint16(tableOffsets[hhea_table] + 34);

  int get numGlyphs => bytes.getUint16(tableOffsets[maxp_table] + 4);

  String get fontName => _fontName;

  bool get unicode => bytes.getUint32(0) == 0x10000;

  // https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6name.html
  void _parseFontName() {
    final int basePosition = tableOffsets[name_table];
    final int count = bytes.getUint16(basePosition + 2);
    final int stringOffset = bytes.getUint16(basePosition + 4);
    int pos = basePosition + 6;
    for (int i = 0; i < count; i++) {
      final int platformID = bytes.getUint16(pos);
      final int nameID = bytes.getUint16(pos + 6);
      final int length = bytes.getUint16(pos + 8);
      final int offset = bytes.getUint16(pos + 10);
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
          _fontName = decodeUtf16(bytes.buffer
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
    final int basePosition = tableOffsets[cmap_table];
    final int numSubTables = bytes.getUint16(basePosition + 2);
    for (int i = 0; i < numSubTables; i++) {
      final int offset = bytes.getUint32(basePosition + i * 8 + 8);
      final int format = bytes.getUint16(basePosition + offset);
      final int length = bytes.getUint16(basePosition + offset + 2);

      switch (format) {
        case 0:
          _parseCMapFormat0(basePosition + offset + 4, length);
          break;

        case 4:
          _parseCMapFormat4(basePosition + offset + 4, length);
          break;
        case 6:
          _parseCMapFormat6(basePosition + offset + 4, length);
          break;
      }
    }
  }

  void _parseCMapFormat0(int basePosition, int length) {
    assert(length == 262);
    for (int i = 0; i < 256; i++) {
      final int charCode = i;
      final int glyphIndex = bytes.getUint8(basePosition + i);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat4(int basePosition, int length) {
    final int segCount = bytes.getUint16(basePosition + 2) ~/ 2;
    final List<int> endCodes = <int>[];
    for (int i = 0; i < segCount; i++) {
      endCodes.add(bytes.getUint16(basePosition + i * 2 + 10));
    }
    final List<int> startCodes = <int>[];
    for (int i = 0; i < segCount; i++) {
      startCodes.add(bytes.getUint16(basePosition + (segCount + i) * 2 + 12));
    }
    final List<int> idDeltas = <int>[];
    for (int i = 0; i < segCount; i++) {
      idDeltas.add(bytes.getUint16(basePosition + (segCount * 2 + i) * 2 + 12));
    }
    final int idRangeOffsetBasePos = basePosition + segCount * 6 + 12;
    final List<int> idRangeOffsets = <int>[];
    for (int i = 0; i < segCount; i++) {
      idRangeOffsets.add(bytes.getUint16(idRangeOffsetBasePos + i * 2));
    }
    for (int s = 0; s < segCount - 1; s++) {
      final int startCode = startCodes[s];
      final int endCode = endCodes[s];
      final int idDelta = idDeltas[s];
      final int idRangeOffset = idRangeOffsets[s];
      final int idRangeOffsetAddress = idRangeOffsetBasePos + s * 2;
      for (int c = startCode; c <= endCode; c++) {
        int glyphIndex;
        if (idRangeOffset == 0) {
          glyphIndex = (idDelta + c) % 65536;
        } else {
          final int glyphIndexAddress =
              idRangeOffset + 2 * (c - startCode) + idRangeOffsetAddress;
          glyphIndex = bytes.getUint16(glyphIndexAddress);
        }
        charToGlyphIndexMap[c] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat6(int basePosition, int length) {
    final int firstCode = bytes.getUint16(basePosition + 2);
    final int entryCount = bytes.getUint16(basePosition + 4);
    for (int i = 0; i < entryCount; i++) {
      final int charCode = firstCode + i;
      final int glyphIndex = bytes.getUint16(basePosition + i * 2 + 6);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseIndexes() {
    final int basePosition = tableOffsets[loca_table];
    final int numGlyphs = this.numGlyphs;
    if (indexToLocFormat == 0) {
      for (int i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint16(basePosition + i * 2) * 2);
      }
    } else {
      for (int i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint32(basePosition + i * 4));
      }
    }
  }

  /// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6glyf.html
  void _parseGlyphs() {
    final int baseOffset = tableOffsets[glyf_table];
    final int hmtxOffset = tableOffsets[hmtx_table];
    final int unitsPerEm = this.unitsPerEm;
    int glyphIndex = 0;
    for (int offset in glyphOffsets) {
      final int xMin = bytes.getInt16(baseOffset + offset + 2); // 2
      final int yMin = bytes.getInt16(baseOffset + offset + 4); // 4
      final int xMax = bytes.getInt16(baseOffset + offset + 6); // 6
      final int yMax = bytes.getInt16(baseOffset + offset + 8); // 8
      final double advanceWidth = glyphIndex < numOfLongHorMetrics
          ? bytes.getInt16(hmtxOffset + glyphIndex * 4).toDouble() / unitsPerEm
          : null;
      glyphInfoMap[glyphIndex] = PdfFontMetrics(
          left: xMin.toDouble() / unitsPerEm,
          top: yMin.toDouble() / unitsPerEm,
          right: xMax.toDouble() / unitsPerEm,
          bottom: yMax.toDouble() / unitsPerEm,
          ascent: ascent.toDouble() / unitsPerEm,
          descent: descent.toDouble() / unitsPerEm,
          advanceWidth: advanceWidth);
      glyphIndex++;
    }
  }

  /// http://stevehanov.ca/blog/?id=143
  TtfGlyphInfo readGlyph(int index) {
    assert(index != null);
    assert(index < glyphOffsets.length);

    final int start = tableOffsets[glyf_table] + glyphOffsets[index];

    final int numberOfContours = bytes.getInt16(start);
    assert(numberOfContours >= -1);

    if (numberOfContours == -1) {
      return _readCompoundGlyph(index, start, start + 10);
    } else {
      return _readSimpleGlyph(index, start, start + 10, numberOfContours);
    }
  }

  TtfGlyphInfo _readSimpleGlyph(
      int glyph, int start, int offset, int numberOfContours) {
    const int X_IS_BYTE = 2;
    const int Y_IS_BYTE = 4;
    const int REPEAT = 8;
    const int X_DELTA = 16;
    const int Y_DELTA = 32;

    int numPoints = 1;

    for (int i = 0; i < numberOfContours; i++) {
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

    final List<int> flags = <int>[];

    for (int i = 0; i < numPoints; i++) {
      final int flag = bytes.getUint8(offset++);
      flags.add(flag);

      if (flag & REPEAT != 0) {
        int repeatCount = bytes.getUint8(offset++);
        assert(repeatCount > 0);
        i += repeatCount;
        while (repeatCount-- > 0) {
          flags.add(flag);
        }
      }
    }

    int byteFlag = X_IS_BYTE;
    int deltaFlag = X_DELTA;
    for (int a = 0; a < 2; a++) {
      for (int i = 0; i < numPoints; i++) {
        final int flag = flags[i];
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
    const int ARG_1_AND_2_ARE_WORDS = 1;
    const int MORE_COMPONENTS = 32;
    const int WE_HAVE_INSTRUCTIONS = 256;

    final List<int> components = <int>[];
    bool hasInstructions = false;
    int flags = MORE_COMPONENTS;

    while (flags & MORE_COMPONENTS != 0) {
      flags = bytes.getUint16(offset);
      final int glyphIndex = bytes.getUint16(offset + 2);
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

  void _parseGsub() {
    // print(fontName);
    // print(tableOffsets);
    //
    // final int basePosition = tableOffsets[gsub_table];
    // print('GSUB Version: ${bytes.getUint32(basePosition).toRadixString(16)}');
    // final int scriptListOffset =
    // bytes.getUint16(basePosition + 4) + basePosition;
    // final int featureListOffset =
    // bytes.getUint16(basePosition + 6) + basePosition;
    // final int lookupListOffset =
    // bytes.getUint16(basePosition + 8) + basePosition;
    // print('GSUB Offsets: $scriptListOffset $featureListOffset $lookupListOffset');
  }
}
