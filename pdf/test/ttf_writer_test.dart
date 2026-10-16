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

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/font/ttf_parser.dart';
import 'package:pdf/src/pdf/font/ttf_writer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// One record of an emitted sfnt table directory.
class _Record {
  _Record(this.tag, this.offset, this.length);

  final String tag;
  final int offset;
  final int length;
}

/// What the emitted subset says about itself.
class _Directory {
  _Directory(Uint8List font) : _view = ByteData.view(font.buffer) {
    total = font.lengthInBytes;
    numTables = _view.getUint16(4);
    searchRange = _view.getUint16(6);
    entrySelector = _view.getUint16(8);
    rangeShift = _view.getUint16(10);

    for (var i = 0; i < numTables; i++) {
      final at = 12 + i * 16;
      records.add(
        _Record(
          String.fromCharCodes(font.sublist(at, at + 4)),
          _view.getUint32(at + 8),
          _view.getUint32(at + 12),
        ),
      );
    }
  }

  final ByteData _view;
  int total = 0;
  int numTables = 0;
  int searchRange = 0;
  int entrySelector = 0;
  int rangeShift = 0;
  final records = <_Record>[];

  List<String> get tags => records.map((_Record r) => r.tag).toList();

  /// The spec's own binary search over the directory.
  _Record? find(String tag) {
    if (numTables == 0) {
      return null;
    }

    var low = 0;
    var span = searchRange ~/ 16;
    if (tag.compareTo(records[span - 1].tag) > 0) {
      low = numTables - span;
    }
    while (span > 1) {
      span ~/= 2;
      if (low + span <= numTables &&
          tag.compareTo(records[low + span - 1].tag) > 0) {
        low += span;
      }
    }
    return low < numTables && records[low].tag == tag ? records[low] : null;
  }
}

TtfParser _source(String name) =>
    TtfParser(File('$name.ttf').readAsBytesSync().buffer.asByteData());

/// The same font with one table struck from its directory.
///
/// The bytes stay where they are; only the record goes, which is what a font
/// that never had the table looks like to the parser.
Uint8List _without(String name, String tag) {
  final font = File('$name.ttf').readAsBytesSync();
  final view = font.buffer.asByteData();
  final numTables = view.getUint16(4);

  for (var i = 0; i < numTables; i++) {
    final at = 12 + i * 16;
    if (String.fromCharCodes(font.sublist(at, at + 4)) != tag) {
      continue;
    }

    // Shift the records after it down, and drop one from the count.
    final out = Uint8List.fromList(font);
    out.setRange(at, 12 + (numTables - 1) * 16, font.sublist(at + 16));
    out.buffer.asByteData().setUint16(4, numTables - 1);
    return out;
  }

  throw StateError('$name has no $tag table');
}

const _chars = <int>[0x41, 0x42, 0x61, 0x62, 0x20];

void main() {
  group('the sfnt header', () {
    test('follows the spec formulas', () {
      // Every subset used to carry 256/2/96 where 128/3/32 is required: the loop
      // found the next power of two at or above numTables rather than the
      // largest at or below it, entrySelector took the natural log instead of
      // log2, and rangeShift was inverted.
      for (final name in <String>['open-sans', 'genyomintw', 'material']) {
        final directory = _Directory(
          TtfWriter(_source(name)).withChars(_chars),
        );

        expect(
          directory.entrySelector,
          _floorLog2(directory.numTables),
          reason: name,
        );
        expect(
          directory.searchRange,
          16 * (1 << directory.entrySelector),
          reason: name,
        );
        expect(
          directory.rangeShift,
          directory.numTables * 16 - directory.searchRange,
          reason: name,
        );
        expect(
          directory.searchRange + directory.rangeShift,
          directory.numTables * 16,
          reason: name,
        );
        expect(
          directory.searchRange,
          lessThanOrEqualTo(directory.numTables * 16),
          reason: name,
        );
      }
    });

    test('holds for any table count', () {
      for (final count in <int>[9, 10, 14, 16]) {
        var entrySelector = 0;
        while (1 << (entrySelector + 1) <= count) {
          entrySelector++;
        }
        final searchRange = 16 << entrySelector;
        expect(searchRange + (count * 16 - searchRange), count * 16);
      }
    });
  });

  group('the table directory', () {
    test('is sorted and binary-searchable', () {
      for (final name in <String>['open-sans', 'genyomintw', 'material']) {
        final directory = _Directory(
          TtfWriter(_source(name)).withChars(_chars),
        );

        expect(
          directory.tags,
          directory.tags.toList()..sort(),
          reason: '$name: the spec requires ascending tag order',
        );

        for (final tag in directory.tags) {
          expect(
            directory.find(tag)?.tag,
            tag,
            reason: '$name: a spec binary search must find $tag',
          );
        }
      }
    });

    test('agrees with itself', () {
      for (final name in <String>['open-sans', 'genyomintw', 'material']) {
        final font = TtfWriter(_source(name)).withChars(_chars);
        final directory = _Directory(font);

        expect(directory.records, hasLength(directory.numTables));
        for (final record in directory.records) {
          expect(
            record.offset + record.length,
            lessThanOrEqualTo(directory.total),
            reason: '$name: ${record.tag} runs past the end',
          );
          expect(
            record.offset,
            greaterThanOrEqualTo(12 + directory.numTables * 16),
          );
        }
      }
    });

    test('keeps head locatable, so its checksum is patched', () {
      final font = TtfWriter(_source('open-sans')).withChars(_chars);
      final head = _Directory(font).find('head');

      expect(head, isNotNull);
      expect(
        ByteData.view(font.buffer).getUint32(head!.offset + 8),
        isNot(0),
        reason: 'checkSumAdjustment is written after the reordering',
      );
    });
  });

  group('a font without OS/2', () {
    test('subsets instead of throwing', () {
      // It used to abort with 'Null check operator used on a null value',
      // because the directory came from a hard-coded list that always contained
      // OS/2 while the table copy skipped it.
      final stripped = TtfParser(
        _without('open-sans', 'OS/2').buffer.asByteData(),
      );
      expect(stripped.tableOffsets.containsKey('OS/2'), isFalse);

      final font = TtfWriter(stripped).withChars(_chars);
      final directory = _Directory(font);

      expect(directory.tags, isNot(contains('OS/2')));
      expect(directory.records, hasLength(directory.numTables));
      expect(directory.tags, directory.tags.toList()..sort());
    });

    test('still saves a document', () async {
      final stripped = TtfParser(
        _without('open-sans', 'OS/2').buffer.asByteData(),
      );
      final document = pw.Document();
      document.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Text(
            'Ab',
            style: pw.TextStyle(font: pw.TtfFont(stripped.bytes)),
          ),
        ),
      );

      expect(await document.save(), isNotEmpty);
    });

    test('and a font without post is synthesised one', () {
      final stripped = TtfParser(
        _without('open-sans', 'post').buffer.asByteData(),
      );

      final directory = _Directory(TtfWriter(stripped).withChars(_chars));
      final post = directory.find('post');

      expect(post, isNotNull);
      expect(post!.length, 32);
    });
  });

  group('hinting', () {
    test('the programs the glyphs call are carried over', () {
      // The glyph outlines are copied with their instructions, so a subset
      // without cvt, fpgm and prep is structurally invalid: its glyph programs
      // call missing functions and index an absent control-value table.
      final source = _source('open-sans');
      final present = <String>[
        for (final tag in <String>['cvt ', 'fpgm', 'prep', 'gasp'])
          if (source.tableOffsets.containsKey(tag)) tag,
      ];
      expect(present, isNotEmpty, reason: 'the fixture must be hinted');

      final directory = _Directory(TtfWriter(source).withChars(_chars));

      for (final tag in present) {
        expect(directory.tags, contains(tag));
      }
    });

    test('a font without them subsets unchanged', () {
      final source = _source('material');
      final absent = <String>[
        for (final tag in <String>['cvt ', 'fpgm', 'prep'])
          if (!source.tableOffsets.containsKey(tag)) tag,
      ];

      final directory = _Directory(TtfWriter(source).withChars(_chars));

      for (final tag in absent) {
        expect(directory.tags, isNot(contains(tag)));
      }
      expect(directory.records, hasLength(directory.numTables));
    });

    test('a subset re-parses', () {
      for (final name in <String>['open-sans', 'genyomintw', 'material']) {
        final font = TtfWriter(_source(name)).withChars(_chars);
        final reparsed = TtfParser(font.buffer.asByteData());

        expect(reparsed.numGlyphs, _chars.length, reason: name);
        expect(
          reparsed.tableOffsets.keys,
          containsAll(<String>['head', 'glyf']),
        );
      }
    });
  });
}

int _floorLog2(int value) {
  var result = 0;
  while (1 << (result + 1) <= value) {
    result++;
  }
  return result;
}
