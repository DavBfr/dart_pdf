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

import 'dart:math' as math;
import 'dart:typed_data';

import 'ttf_parser.dart';

/// Generate a TTF font copy with the minimal number of glyph to embed
/// into the PDF document
///
/// https://opentype.js.org/
/// https://github.com/HinTak/Font-Validator
class TtfWriter {
  /// Create a TrueType Writer object
  TtfWriter(this.ttf);

  /// Original TrueType file
  final TtfParser ttf;

  int _calcTableChecksum(ByteData table) {
    assert(table.lengthInBytes % 4 == 0);
    var sum = 0;
    for (var i = 0; i < table.lengthInBytes - 3; i += 4) {
      sum = (sum + table.getUint32(i)) & 0xffffffff;
    }
    return sum;
  }

  void _updateCompoundGlyph(TtfGlyphInfo glyph, Map<int, int?> compoundMap) {
    const arg1And2AreWords = 1;
    const weHaveAScale = 8;
    const moreComponents = 32;
    const weHaveAnXAndYScale = 64;
    const weHaveATwoByTwo = 128;

    var offset = 10;
    final bytes = glyph.data.buffer.asByteData(
      glyph.data.offsetInBytes,
      glyph.data.lengthInBytes,
    );
    var flags = moreComponents;

    while (flags & moreComponents != 0) {
      if (offset + 4 > bytes.lengthInBytes) {
        break;
      }
      flags = bytes.getUint16(offset);
      final glyphIndex = bytes.getUint16(offset + 2);
      final newIndex = compoundMap[glyphIndex];
      if (newIndex != null) {
        bytes.setUint16(offset + 2, newIndex);
      }
      offset += (flags & arg1And2AreWords != 0) ? 8 : 6;
      if (flags & weHaveAScale != 0) {
        offset += 2;
      } else if (flags & weHaveAnXAndYScale != 0) {
        offset += 4;
      } else if (flags & weHaveATwoByTwo != 0) {
        offset += 8;
      }
    }
  }

  int _wordAlign(int offset, [int align = 4]) {
    return offset + ((align - (offset % align)) % align);
  }

  /// Write this list of glyphs
  Uint8List withChars(List<int> chars) {
    final tables = <String, Uint8List>{};
    final tablesLength = <String, int>{};

    // Create the glyphs table.
    //
    // The caller writes /CIDToGIDMap /Identity and uses the position in
    // `chars` as the CID, so subset glyph i must be the glyph for chars[i],
    // with no gaps. Several characters legitimately share one source glyph -
    // canonical duplicates such as U+0394 and U+2206, every codepoint the font
    // does not map (all funnelled onto glyph 0), and the Arabic presentation
    // forms this package points at their base letter - so the mapping from
    // characters to source glyphs is many-to-one and each CID needs its own
    // copy of the outline.
    final glyphsInfo = <TtfGlyphInfo>[];
    final sourceGlyphs = <int, TtfGlyphInfo>{};
    // Component glyphs of compound glyphs, which live after the CID region.
    final compounds = <int, int>{};

    TtfGlyphInfo readSource(int glyphIndex) {
      final cached = sourceGlyphs[glyphIndex];
      if (cached != null) {
        return cached;
      }
      final glyph = ttf.readGlyph(glyphIndex).copy();
      sourceGlyphs[glyphIndex] = glyph;
      for (final component in glyph.compounds) {
        compounds[component] = -1;
        readSource(component);
      }
      return glyph;
    }

    for (final char in chars) {
      final glyphIndex = ttf.charToGlyphIndexMap[char] ?? 0;

      // A glyph the font does not have. The space used to be special-cased here
      // too, because readGlyph returned the next glyph's outline for it; now an
      // empty glyph reads as empty, so a font whose space really does carry an
      // outline keeps it.
      if (glyphIndex >= ttf.glyphOffsets.length) {
        assert(() {
          print('Glyph $glyphIndex not in the font ${ttf.fontName}');
          return true;
        }());
        // Still occupy this CID slot: skipping it would shift every later
        // character onto the wrong glyph.
        glyphsInfo.add(TtfGlyphInfo(glyphIndex, Uint8List(0), const <int>[]));
        continue;
      }

      // One copy per CID: _updateCompoundGlyph rewrites the component indices
      // in place, so two slots must not share a buffer.
      glyphsInfo.add(readSource(glyphIndex).copy());
    }

    // Append the component glyphs after the CID region and record where they
    // landed, so the compound outlines can point at them.
    for (final component in compounds.keys.toList()) {
      compounds[component] = glyphsInfo.length;
      glyphsInfo.add(readSource(component).copy());
    }

    // update compound indices
    for (final glyph in glyphsInfo) {
      if (glyph.compounds.isNotEmpty) {
        _updateCompoundGlyph(glyph, compounds);
      }
    }

    var glyphsTableLength = 0;
    for (final glyph in glyphsInfo) {
      glyphsTableLength = _wordAlign(
        glyphsTableLength + glyph.data.lengthInBytes,
      );
    }
    var offset = 0;
    final glyphsTable = Uint8List(_wordAlign(glyphsTableLength));
    tables[TtfParser.glyf_table] = glyphsTable;
    tablesLength[TtfParser.glyf_table] = glyphsTableLength;

    // Loca
    if (ttf.indexToLocFormat == 0) {
      tables[TtfParser.loca_table] = Uint8List(
        _wordAlign((glyphsInfo.length + 1) * 2),
      ); // uint16
      tablesLength[TtfParser.loca_table] = (glyphsInfo.length + 1) * 2;
    } else {
      tables[TtfParser.loca_table] = Uint8List(
        _wordAlign((glyphsInfo.length + 1) * 4),
      ); // uint32
      tablesLength[TtfParser.loca_table] = (glyphsInfo.length + 1) * 4;
    }

    {
      final loca = tables[TtfParser.loca_table]!.buffer.asByteData();
      var index = 0;
      for (final glyph in glyphsInfo) {
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
      if (ttf.indexToLocFormat == 0) {
        loca.setUint16(index, offset ~/ 2);
      } else {
        loca.setUint32(index, offset);
      }
    }

    // Copy some tables from the original file
    for (final tn in {
      TtfParser.head_table,
      TtfParser.maxp_table,
      TtfParser.hhea_table,
      TtfParser.os_2_table,
    }) {
      final start = ttf.tableOffsets[tn];
      if (start == null) {
        continue;
      }
      final len = ttf.tableSize[tn]!;
      final data = Uint8List.fromList(
        ttf.bytes.buffer.asUint8List(start, _wordAlign(len)),
      );
      tables[tn] = data;
      tablesLength[tn] = len;
    }

    tables[TtfParser.head_table]!.buffer.asByteData().setUint32(
      8,
      0,
    ); // checkSumAdjustment
    tables[TtfParser.maxp_table]!.buffer.asByteData().setUint16(
      4,
      glyphsInfo.length,
    );
    tables[TtfParser.hhea_table]!.buffer.asByteData().setUint16(
      34,
      glyphsInfo.length,
    ); // numOfLongHorMetrics

    {
      // post Table
      final start = ttf.tableOffsets[TtfParser.post_table]!;
      const len = 32;
      final data = Uint8List.fromList(
        ttf.bytes.buffer.asUint8List(start, _wordAlign(len)),
      );
      data.buffer.asByteData().setUint32(0, 0x00030000); // Version 3.0 no names
      tables[TtfParser.post_table] = data;
      tablesLength[TtfParser.post_table] = len;
    }

    {
      // HMTX table
      final len = 4 * glyphsInfo.length;
      final hmtx = Uint8List(_wordAlign(len));
      final hmtxOffset = ttf.tableOffsets[TtfParser.hmtx_table]!;
      final hmtxData = hmtx.buffer.asByteData();
      final numOfLongHorMetrics = ttf.numOfLongHorMetrics;
      final defaultAdvanceWidth = ttf.bytes.getUint16(
        hmtxOffset + (numOfLongHorMetrics - 1) * 4,
      );
      var index = 0;
      for (final glyph in glyphsInfo) {
        final advanceWidth = glyph.index < numOfLongHorMetrics
            ? ttf.bytes.getUint16(hmtxOffset + glyph.index * 4)
            : defaultAdvanceWidth;
        final leftBearing = glyph.index < numOfLongHorMetrics
            ? ttf.bytes.getInt16(hmtxOffset + glyph.index * 4 + 2)
            : ttf.bytes.getInt16(
                hmtxOffset +
                    numOfLongHorMetrics * 4 +
                    (glyph.index - numOfLongHorMetrics) * 2,
              );
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
      final cmap = Uint8List(_wordAlign(len));
      final cmapData = cmap.buffer.asByteData();
      cmapData.setUint16(0, 0); // Table version number
      cmapData.setUint16(2, 1); // Number of encoding tables that follow.
      cmapData.setUint16(4, 3); // Platform ID
      cmapData.setUint16(6, 10); // Platform-specific encoding ID
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
      // name table
      const len = 18;
      final nameBuf = Uint8List(_wordAlign(len));
      final nameData = nameBuf.buffer.asByteData();
      nameData.setUint16(0, 0); // Table version number 0
      nameData.setUint16(2, 0); // Count 0 -> no names
      nameData.setUint16(4, 6); // Storage Offset
      tables[TtfParser.name_table] = nameBuf;
      tablesLength[TtfParser.name_table] = len;
    }

    {
      final bytes = BytesBuilder();

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
      var headOffset = 0;

      final tableKeys = [
        TtfParser.head_table,
        TtfParser.hhea_table,
        TtfParser.maxp_table,
        TtfParser.os_2_table,
        TtfParser.hmtx_table,
        TtfParser.cmap_table,
        TtfParser.loca_table,
        TtfParser.glyf_table,
        TtfParser.name_table,
        TtfParser.post_table,
      ];

      for (final name in tableKeys) {
        final data = tables[name]!;
        final runes = name.runes.toList();
        start.setUint8(12 + count * 16, runes[0]);
        start.setUint8(12 + count * 16 + 1, runes[1]);
        start.setUint8(12 + count * 16 + 2, runes[2]);
        start.setUint8(12 + count * 16 + 3, runes[3]);
        start.setUint32(
          12 + count * 16 + 4,
          _calcTableChecksum(data.buffer.asByteData()),
        ); // checkSum
        start.setUint32(12 + count * 16 + 8, offset); // offset
        start.setUint32(12 + count * 16 + 12, tablesLength[name]!); // length

        if (name == 'head') {
          headOffset = offset;
        }
        offset += data.lengthInBytes;
        count++;
      }
      bytes.add(start.buffer.asUint8List());

      for (final name in tableKeys) {
        final data = tables[name]!;
        bytes.add(data.buffer.asUint8List());
      }

      final output = bytes.toBytes();

      final crc = 0xB1B0AFBA - _calcTableChecksum(output.buffer.asByteData());
      output.buffer.asByteData().setUint32(
        headOffset + 8,
        crc & 0xffffffff,
      ); // checkSumAdjustment

      return output;
    }
  }
}
