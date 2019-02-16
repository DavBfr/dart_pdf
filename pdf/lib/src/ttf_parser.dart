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

part of pdf;

class TtfParser {
  TtfParser(this.bytes) {
    final int numTables = bytes.getUint16(4);

    for (int i = 0; i < numTables; i++) {
      final String name = utf8.decode(bytes.buffer.asUint8List(i * 16 + 12, 4));
      final int offset = bytes.getUint32(i * 16 + 20);
      _tableOffsets[name] = offset;
    }

    _parseFontName();
    _parseHmtx();
    _parseCMap();
    _parseIndexes();
    _parseGlyf();
  }

  static const String _HEAD = 'head';
  static const String _NAME = 'name';
  static const String _HMTX = 'hmtx';
  static const String _HHEA = 'hhea';
  static const String _CMAP = 'cmap';
  static const String _MAXP = 'maxp';
  static const String _LOCA = 'loca';
  static const String _GLYF = 'glyf';

  final ByteData bytes;
  final Map<String, int> _tableOffsets = <String, int>{};
  String _fontName;
  final List<double> advanceWidth = <double>[];
  final Map<int, int> charToGlyphIndexMap = <int, int>{};
  final List<int> glyphOffsets = <int>[];
  final Map<int, PdfRect> glyphInfoMap = <int, PdfRect>{};

  int get unitsPerEm => bytes.getUint16(_tableOffsets[_HEAD] + 18);

  int get xMin => bytes.getInt16(_tableOffsets[_HEAD] + 36);

  int get yMin => bytes.getInt16(_tableOffsets[_HEAD] + 38);

  int get xMax => bytes.getInt16(_tableOffsets[_HEAD] + 40);

  int get yMax => bytes.getInt16(_tableOffsets[_HEAD] + 42);

  int get indexToLocFormat => bytes.getInt16(_tableOffsets[_HEAD] + 50);

  int get ascent => bytes.getInt16(_tableOffsets[_HHEA] + 4);

  int get descent => bytes.getInt16(_tableOffsets[_HHEA] + 6);

  int get numOfLongHorMetrics => bytes.getInt16(_tableOffsets[_HHEA] + 34);

  int get numGlyphs => bytes.getInt16(_tableOffsets[_MAXP] + 4);

  String get fontName => _fontName;

  void _parseFontName() {
    final int basePosition = _tableOffsets[_NAME];
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
        _fontName = utf8.decode(bytes.buffer
            .asUint8List(basePosition + stringOffset + offset, length));
        return;
      }
    }
    _fontName = hashCode.toString();
  }

  void _parseHmtx() {
    final int offset = _tableOffsets[_HMTX];
    final int unitsPerEm = this.unitsPerEm;
    for (int i = 0; i < numOfLongHorMetrics; i++) {
      advanceWidth.add(bytes.getInt16(offset + i * 4).toDouble() / unitsPerEm);
    }
  }

  void _parseCMap() {
    final int basePosition = _tableOffsets[_CMAP];
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
    final int basePosition = _tableOffsets[_LOCA];
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

  void _parseGlyf() {
    final int baseOffset = _tableOffsets[_GLYF];
    final int unitsPerEm = this.unitsPerEm;
    int glyphIndex = 0;
    for (int offset in glyphOffsets) {
      final int xMin = bytes.getInt16(baseOffset + offset + 2); // 2
      final int yMin = bytes.getInt16(baseOffset + offset + 4); // 4
      final int xMax = bytes.getInt16(baseOffset + offset + 6); // 6
      final int yMax = bytes.getInt16(baseOffset + offset + 8); // 8
      glyphInfoMap[glyphIndex] = PdfRect(
          xMin.toDouble() / unitsPerEm,
          yMin.toDouble() / unitsPerEm,
          xMax.toDouble() / unitsPerEm,
          yMax.toDouble() / unitsPerEm);
      glyphIndex++;
    }
  }
}
