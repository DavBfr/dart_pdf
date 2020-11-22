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

/// Generate a TTF font copy with the minimal number of glyph to embedd
/// into the PDF document
///
/// https://opentype.js.org/
class TtfWriter {
  /// Create a Truetype Writer object
  TtfWriter(this.ttf);

  /// original truetype file
  final TtfParser ttf;

  int _calcTableChecksum(ByteData table) {
    assert(table.lengthInBytes % 4 == 0);
    var sum = 0;
    for (var i = 0; i < table.lengthInBytes - 3; i += 4) {
      sum = (sum + table.getUint32(i)) & 0xffffffff;
    }
    return sum;
  }

  void _updateCompoundGlyph(TtfGlyphInfo glyph, Map<int, int> compoundMap) {
    const ARG_1_AND_2_ARE_WORDS = 1;
    const MORE_COMPONENTS = 32;

    var offset = 10;
    final bytes = glyph.data.buffer
        .asByteData(glyph.data.offsetInBytes, glyph.data.lengthInBytes);
    var flags = MORE_COMPONENTS;

    while (flags & MORE_COMPONENTS != 0) {
      flags = bytes.getUint16(offset);
      final glyphIndex = bytes.getUint16(offset + 2);
      bytes.setUint16(offset + 2, compoundMap[glyphIndex]);
      offset += (flags & ARG_1_AND_2_ARE_WORDS != 0) ? 8 : 6;
    }
  }

  int _wordAlign(int offset, [int align = 2]) {
    return offset + ((align - (offset % align)) % align);
  }

  /// Write this list of glyphs
  Uint8List withChars(List<int> chars) {
    final tables = <String, Uint8List>{};
    final tablesLength = <String, int>{};

    // Create the glyphs table
    final glyphsInfo = <TtfGlyphInfo>[];
    final compounds = <int, int>{};

    for (var index = 0; index < chars.length; index++) {
      if (chars[index] == 32) {
        final glyph = TtfGlyphInfo(32, Uint8List(0), const <int>[]);
        glyphsInfo.add(glyph);
        continue;
      }

      final glyph =
          ttf.readGlyph(ttf.charToGlyphIndexMap[chars[index]] ?? 0).copy();
      for (var g in glyph.compounds) {
        compounds[g] = null;
      }
      glyphsInfo.add(glyph);
    }

    // Add compound glyphs
    for (var compound in compounds.keys) {
      final index = glyphsInfo.firstWhere(
          (TtfGlyphInfo glyph) => glyph.index == compound,
          orElse: () => null);
      if (index != null) {
        compounds[compound] = glyphsInfo.indexOf(index);
        assert(compounds[compound] >= 0, 'Unable to find the glyph');
      } else {
        compounds[compound] = glyphsInfo.length;
        final glyph = ttf.readGlyph(compound);
        assert(glyph.compounds.isEmpty, 'This is not a simple glyph');
        glyphsInfo.add(glyph);
      }
    }

    // Add one last empty glyph
    final glyph = TtfGlyphInfo(32, Uint8List(0), const <int>[]);
    glyphsInfo.add(glyph);

    // update compound indices
    for (var glyph in glyphsInfo) {
      if (glyph.compounds.isNotEmpty) {
        _updateCompoundGlyph(glyph, compounds);
      }
    }

    var glyphsTableLength = 0;
    for (var glyph in glyphsInfo) {
      glyphsTableLength =
          _wordAlign(glyphsTableLength + glyph.data.lengthInBytes);
    }
    var offset = 0;
    final glyphsTable = Uint8List(_wordAlign(glyphsTableLength, 4));
    tables[TtfParser.glyf_table] = glyphsTable;
    tablesLength[TtfParser.glyf_table] = glyphsTableLength;

    // Loca
    if (ttf.indexToLocFormat == 0) {
      tables[TtfParser.loca_table] =
          Uint8List(_wordAlign(glyphsInfo.length * 2, 4)); // uint16
      tablesLength[TtfParser.loca_table] = glyphsInfo.length * 2;
    } else {
      tables[TtfParser.loca_table] =
          Uint8List(_wordAlign(glyphsInfo.length * 4, 4)); // uint32
      tablesLength[TtfParser.loca_table] = glyphsInfo.length * 4;
    }

    {
      final loca = tables[TtfParser.loca_table].buffer.asByteData();
      var index = 0;
      for (var glyph in glyphsInfo) {
        if (ttf.indexToLocFormat == 0) {
          loca.setUint16(index, offset ~/ 2);
          index += 2;
        } else {
          loca.setUint32(index, offset);
          index += 4;
        }
        glyphsTable.setAll(offset, glyph.data);
        offset = _wordAlign(offset + glyph.data.lengthInBytes);
      }
    }

    {
      // Head table
      final start = ttf.tableOffsets[TtfParser.head_table];
      final len = ttf.tableSize[TtfParser.head_table];
      final head = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      head.buffer.asByteData().setUint32(8, 0); // checkSumAdjustment
      tables[TtfParser.head_table] = head;
      tablesLength[TtfParser.head_table] = len;
    }

    {
      // MaxP table
      final start = ttf.tableOffsets[TtfParser.maxp_table];
      final len = ttf.tableSize[TtfParser.maxp_table];
      final maxp = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      maxp.buffer.asByteData().setUint16(4, glyphsInfo.length);
      tables[TtfParser.maxp_table] = maxp;
      tablesLength[TtfParser.maxp_table] = len;
    }

    {
      // HHEA table
      final start = ttf.tableOffsets[TtfParser.hhea_table];
      final len = ttf.tableSize[TtfParser.hhea_table];
      final hhea = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      hhea.buffer
          .asByteData()
          .setUint16(34, glyphsInfo.length); // numOfLongHorMetrics

      tables[TtfParser.hhea_table] = hhea;
      tablesLength[TtfParser.hhea_table] = len;
    }

    {
      // HMTX table
      final len = 4 * glyphsInfo.length;
      final hmtx = Uint8List(_wordAlign(len, 4));
      final hmtxOffset = ttf.tableOffsets[TtfParser.hmtx_table];
      final hmtxData = hmtx.buffer.asByteData();
      final numOfLongHorMetrics = ttf.numOfLongHorMetrics;
      final defaultadvanceWidth =
          ttf.bytes.getUint16(hmtxOffset + (numOfLongHorMetrics - 1) * 4);
      var index = 0;
      for (var glyph in glyphsInfo) {
        final advanceWidth = glyph.index < numOfLongHorMetrics
            ? ttf.bytes.getUint16(hmtxOffset + glyph.index * 4)
            : defaultadvanceWidth;
        final leftBearing = glyph.index < numOfLongHorMetrics
            ? ttf.bytes.getInt16(hmtxOffset + glyph.index * 4 + 2)
            : ttf.bytes.getInt16(hmtxOffset +
                numOfLongHorMetrics * 4 +
                (glyph.index - numOfLongHorMetrics) * 2);
        hmtxData.setUint16(index, advanceWidth);
        hmtxData.setInt16(index + 2, leftBearing);
        index += 4;
      }
      tables[TtfParser.hmtx_table] = hmtx;
      tablesLength[TtfParser.hmtx_table] = len;
    }

    {
      // CMAP table
      const len = 40;
      final cmap = Uint8List(_wordAlign(len, 4));
      final cmapData = cmap.buffer.asByteData();
      cmapData.setUint16(0, 0); // Table version number
      cmapData.setUint16(2, 1); // Number of encoding tables that follow.
      cmapData.setUint16(4, 3); // Platform ID
      cmapData.setUint16(6, 1); // Platform-specific encoding ID
      cmapData.setUint32(8, 12); // Offset from beginning of table
      cmapData.setUint16(12, 12); // Table format
      cmapData.setUint32(16, 28); // Table length
      cmapData.setUint32(20, 1); // Table language
      cmapData.setUint32(24, 1); // numGroups
      cmapData.setUint32(28, 32); // startCharCode
      cmapData.setUint32(32, chars.length + 31); // endCharCode
      cmapData.setUint32(36, 0); // startGlyphID

      tables[TtfParser.cmap_table] = cmap;
      tablesLength[TtfParser.cmap_table] = len;
    }

    {
      final bytes = <int>[];

      final numTables = tables.length;

      // Create the file header
      final start = ByteData(12 + numTables * 16);
      start.setUint32(0, 0x00010000);
      start.setUint16(4, numTables);
      var pot = numTables;
      while (pot & (pot - 1) != 0) {
        pot++;
      }
      start.setUint16(6, pot * 16);
      start.setUint16(8, math.log(pot).toInt());
      start.setUint16(10, pot * 16 - numTables * 16);

      // Create the table directory
      var count = 0;
      var offset = 12 + numTables * 16;
      tables.forEach((String name, Uint8List data) {
        final runes = name.runes.toList();
        start.setUint8(12 + count * 16, runes[0]);
        start.setUint8(12 + count * 16 + 1, runes[1]);
        start.setUint8(12 + count * 16 + 2, runes[2]);
        start.setUint8(12 + count * 16 + 3, runes[3]);
        start.setUint32(12 + count * 16 + 4,
            _calcTableChecksum(data.buffer.asByteData())); // checkSum
        start.setUint32(12 + count * 16 + 8, offset); // offset
        start.setUint32(12 + count * 16 + 12, tablesLength[name]); // length
        offset += data.lengthInBytes;
        count++;
      });
      bytes.addAll(start.buffer.asUint8List());

      tables.forEach((String name, Uint8List data) {
        bytes.addAll(data.buffer.asUint8List());
      });

      return Uint8List.fromList(bytes);
    }
  }
}
