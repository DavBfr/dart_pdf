/*
 * Copyright (C) 2018, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class TtfParser {
  static const _HEAD = "head";
  static const _NAME = "name";
  static const _HMTX = "hmtx";
  static const _HHEA = "hhea";
  static const _CMAP = "cmap";
  static const _MAXP = "maxp";
  static const _LOCA = "loca";
  static const _GLYF = "glyf";

  final ByteData bytes;
  final _tableOffsets = Map<String, int>();
  String _fontName;
  final advanceWidth = List<double>();
  final charToGlyphIndexMap = Map<int, int>();
  final glyphOffsets = List<int>();
  final glyphInfoMap = Map<int, PdfRect>();

  TtfParser(this.bytes) {
    final numTables = bytes.getUint16(4);

    for (var i = 0; i < numTables; i++) {
      final name = utf8.decode(bytes.buffer.asUint8List(i * 16 + 12, 4));
      final offset = bytes.getUint32(i * 16 + 20);
      _tableOffsets[name] = offset;
    }

    _parseFontName();
    _parseHmtx();
    _parseCMap();
    _parseIndexes();
    _parseGlyf();
  }

  get unitsPerEm => bytes.getUint16(_tableOffsets[_HEAD] + 18);

  get xMin => bytes.getInt16(_tableOffsets[_HEAD] + 36);

  get yMin => bytes.getInt16(_tableOffsets[_HEAD] + 38);

  get xMax => bytes.getInt16(_tableOffsets[_HEAD] + 40);

  get yMax => bytes.getInt16(_tableOffsets[_HEAD] + 42);

  get indexToLocFormat => bytes.getInt16(_tableOffsets[_HEAD] + 50);

  get ascent => bytes.getInt16(_tableOffsets[_HHEA] + 4);

  get descent => bytes.getInt16(_tableOffsets[_HHEA] + 6);

  get numOfLongHorMetrics => bytes.getInt16(_tableOffsets[_HHEA] + 34);

  get numGlyphs => bytes.getInt16(_tableOffsets[_MAXP] + 4);

  bool get unicode => bytes.getUint32(0) == 0x10000;

  get fontName => _fontName;

  void _parseFontName() {
    final basePosition = _tableOffsets[_NAME];
    final count = bytes.getUint16(basePosition + 2);
    final stringOffset = bytes.getUint16(basePosition + 4);
    int pos = basePosition + 6;
    for (var i = 0; i < count; i++) {
      int platformID = bytes.getUint16(pos);
      int nameID = bytes.getUint16(pos + 6);
      int length = bytes.getUint16(pos + 8);
      int offset = bytes.getUint16(pos + 10);
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
    final offset = _tableOffsets[_HMTX];
    final unitsPerEm = this.unitsPerEm;
    for (var i = 0; i < numOfLongHorMetrics; i++) {
      advanceWidth.add(bytes.getInt16(offset + i * 4).toDouble() / unitsPerEm);
    }
  }

  void _parseCMap() {
    final basePosition = _tableOffsets[_CMAP];
    final numSubTables = bytes.getUint16(basePosition + 2);
    for (var i = 0; i < numSubTables; i++) {
      final offset = bytes.getUint32(basePosition + i * 8 + 8);
      final format = bytes.getUint16(basePosition + offset);
      final length = bytes.getUint16(basePosition + offset + 2);

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
    for (var i = 0; i < 256; i++) {
      int charCode = i;
      int glyphIndex = bytes.getUint8(basePosition + i);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseCMapFormat4(int basePosition, int length) {
    final segCount = bytes.getUint16(basePosition + 2) ~/ 2;
    final endCodes = List<int>();
    for (var i = 0; i < segCount; i++) {
      endCodes.add(bytes.getUint16(basePosition + i * 2 + 10));
    }
    final startCodes = List<int>();
    for (var i = 0; i < segCount; i++) {
      startCodes.add(bytes.getUint16(basePosition + (segCount + i) * 2 + 12));
    }
    final idDeltas = List<int>();
    for (var i = 0; i < segCount; i++) {
      idDeltas.add(bytes.getUint16(basePosition + (segCount * 2 + i) * 2 + 12));
    }
    final idRangeOffsetBasePos = basePosition + segCount * 6 + 12;
    final idRangeOffsets = List<int>();
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
        var glyphIndex;
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

  void _parseCMapFormat6(int basePosition, int length) {
    final firstCode = bytes.getUint16(basePosition + 2);
    final entryCount = bytes.getUint16(basePosition + 4);
    for (var i = 0; i < entryCount; i++) {
      final charCode = firstCode + i;
      final glyphIndex = bytes.getUint16(basePosition + i * 2 + 6);
      if (glyphIndex > 0) {
        charToGlyphIndexMap[charCode] = glyphIndex;
      }
    }
  }

  void _parseIndexes() {
    final basePosition = _tableOffsets[_LOCA];
    final numGlyphs = this.numGlyphs;
    if (indexToLocFormat == 0) {
      for (var i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint16(basePosition + i * 2) * 2);
      }
    } else {
      for (var i = 0; i < numGlyphs; i++) {
        glyphOffsets.add(bytes.getUint32(basePosition + i * 4));
      }
    }
  }

  void _parseGlyf() {
    final baseOffset = _tableOffsets[_GLYF];
    final unitsPerEm = this.unitsPerEm;
    int glyphIndex = 0;
    for (var offset in glyphOffsets) {
      final xMin = bytes.getInt16(baseOffset + offset + 2); // 2
      final yMin = bytes.getInt16(baseOffset + offset + 4); // 4
      final xMax = bytes.getInt16(baseOffset + offset + 6); // 6
      final yMax = bytes.getInt16(baseOffset + offset + 8); // 8
      glyphInfoMap[glyphIndex] = PdfRect(
          xMin.toDouble() / unitsPerEm,
          yMin.toDouble() / unitsPerEm,
          xMax.toDouble() / unitsPerEm,
          yMax.toDouble() / unitsPerEm);
      glyphIndex++;
    }
  }
}
