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

/// https://opentype.js.org/
class TtfWriter {
  TtfWriter(this.ttf);

  final TtfParser ttf;

  int _calcTableChecksum(ByteData table) {
    assert(table.lengthInBytes % 4 == 0);
    int sum = 0;
    for (int i = 0; i < table.lengthInBytes - 3; i += 4) {
      sum = (sum + table.getUint32(i)) & 0xffffffff;
    }
    return sum;
  }

  void _updateCompoundGlyph(TtfGlyphInfo glyph, Map<int, int> compoundMap) {
    const int ARG_1_AND_2_ARE_WORDS = 1;
    const int MORE_COMPONENTS = 32;

    int offset = 10;
    final ByteData bytes = glyph.data.buffer
        .asByteData(glyph.data.offsetInBytes, glyph.data.lengthInBytes);
    int flags = MORE_COMPONENTS;

    while (flags & MORE_COMPONENTS != 0) {
      flags = bytes.getUint16(offset);
      final int glyphIndex = bytes.getUint16(offset + 2);
      bytes.setUint16(offset + 2, compoundMap[glyphIndex]);
      offset += (flags & ARG_1_AND_2_ARE_WORDS != 0) ? 8 : 6;
    }
  }

  int _wordAlign(int offset, [int align = 2]) {
    return offset + ((align - (offset % align)) % align);
  }

  Uint8List withChars(List<int> chars) {
    final Map<String, Uint8List> tables = <String, Uint8List>{};
    final Map<String, int> tablesLength = <String, int>{};

    // Create the glyphs table
    final List<TtfGlyphInfo> glyphsInfo = <TtfGlyphInfo>[];
    final Map<int, int> compounds = <int, int>{};

    for (int index = 0; index < chars.length; index++) {
      if (chars[index] == 32) {
        final TtfGlyphInfo glyph = TtfGlyphInfo(32, Uint8List(0), <int>[]);
        glyphsInfo.add(glyph);
        continue;
      }

      final TtfGlyphInfo glyph =
          ttf.readGlyph(ttf.charToGlyphIndexMap[chars[index]] ?? 0);
      for (int g in glyph.compounds) {
        compounds[g] = null;
      }
      glyphsInfo.add(glyph);
    }

    // Add compound glyphs
    for (int compound in compounds.keys) {
      final int index = chars.indexOf(compound);
      if (index >= 0) {
        compounds[compound] = index;
      } else {
        compounds[compound] = glyphsInfo.length;
        final TtfGlyphInfo glyph = ttf.readGlyph(compound);
        assert(glyph.compounds.isEmpty); // This is a simple glyph
        glyphsInfo.add(glyph);
      }
    }

    // Add one last empty glyph
    final TtfGlyphInfo glyph = TtfGlyphInfo(32, Uint8List(0), <int>[]);
    glyphsInfo.add(glyph);

    // update compound indices
    for (TtfGlyphInfo glyph in glyphsInfo) {
      if (glyph.compounds.isNotEmpty) {
        _updateCompoundGlyph(glyph, compounds);
      }
    }

    int glyphsTableLength = 0;
    for (TtfGlyphInfo glyph in glyphsInfo) {
      glyphsTableLength =
          _wordAlign(glyphsTableLength + glyph.data.lengthInBytes);
    }
    int offset = 0;
    final Uint8List glyphsTable = Uint8List(_wordAlign(glyphsTableLength, 4));
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
      final ByteData loca = tables[TtfParser.loca_table].buffer.asByteData();
      int index = 0;
      for (TtfGlyphInfo glyph in glyphsInfo) {
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
      final int start = ttf.tableOffsets[TtfParser.head_table];
      final int len = ttf.tableSize[TtfParser.head_table];
      final Uint8List head = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      head.buffer.asByteData().setUint32(8, 0); // checkSumAdjustment
      tables[TtfParser.head_table] = head;
      tablesLength[TtfParser.head_table] = len;
    }

    {
      // MaxP table
      final int start = ttf.tableOffsets[TtfParser.maxp_table];
      final int len = ttf.tableSize[TtfParser.maxp_table];
      final Uint8List maxp = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      maxp.buffer.asByteData().setUint16(4, glyphsInfo.length);
      tables[TtfParser.maxp_table] = maxp;
      tablesLength[TtfParser.maxp_table] = len;
    }

    {
      // HHEA table
      final int start = ttf.tableOffsets[TtfParser.hhea_table];
      final int len = ttf.tableSize[TtfParser.hhea_table];
      final Uint8List hhea = Uint8List.fromList(
          ttf.bytes.buffer.asUint8List(start, _wordAlign(len, 4)));
      hhea.buffer
          .asByteData()
          .setUint16(34, glyphsInfo.length); // numOfLongHorMetrics

      tables[TtfParser.hhea_table] = hhea;
      tablesLength[TtfParser.hhea_table] = len;
    }

    {
      // HMTX table
      final int len = 4 * glyphsInfo.length;
      final Uint8List hmtx = Uint8List(_wordAlign(len, 4));
      final int hmtxOffset = ttf.tableOffsets[TtfParser.hmtx_table];
      final ByteData hmtxData = hmtx.buffer.asByteData();
      int index = 0;
      for (TtfGlyphInfo glyph in glyphsInfo) {
        hmtxData.setUint32(
            index, ttf.bytes.getInt32(hmtxOffset + glyph.index * 4));
        index += 4;
      }
      tables[TtfParser.hmtx_table] = hmtx;
      tablesLength[TtfParser.hmtx_table] = len;
    }

    {
      // CMAP table
      final Uint8List cmap = Uint8List(_wordAlign(0x112, 4));
      cmap.setAll(3, <int>[1, 0, 1, 0, 0, 0, 0, 0, 12, 0, 0, 1, 6]);
      final ByteData cmapData = cmap.buffer.asByteData();
      for (int i = 1; i < chars.length; i++) {
        cmapData.setUint8(i + 18, i);
      }
      tables[TtfParser.cmap_table] = cmap;
      tablesLength[TtfParser.cmap_table] = 0x112;
    }

    {
      final List<int> bytes = <int>[];

      final int numTables = tables.length;

      // Create the file header
      final ByteData start = ByteData(12 + numTables * 16);
      start.setUint32(0, 0x00010000);
      start.setUint16(4, numTables);
      int pot = numTables;
      while (pot & (pot - 1) != 0) {
        pot++;
      }
      start.setUint16(6, pot * 16);
      start.setUint16(8, math.log(pot).toInt());
      start.setUint16(10, pot * 16 - numTables * 16);

      // Create the table directory
      int count = 0;
      int offset = 12 + numTables * 16;
      tables.forEach((String name, Uint8List data) {
        final List<int> runes = name.runes.toList();
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
