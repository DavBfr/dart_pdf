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
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// One IFD entry, as it appears on the wire.
class Entry {
  Entry(this.tag, this.type, this.count, this.data);

  final int tag;
  final int type;

  /// The declared value count, which need not match [data] - that is the point
  /// of several of these tests.
  final int count;

  /// The value's bytes. Four or fewer go in the value field itself, as the format
  /// requires; more go out of line with the field pointing at them.
  final List<int> data;
}

void _u16(List<int> to, int v) => to.addAll(<int>[(v >> 8) & 0xff, v & 0xff]);

void _u32(List<int> to, int v) => to.addAll(<int>[
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
]);

/// An APP1 EXIF segment holding [entries]: big-endian TIFF throughout.
List<int> exifSegment(List<Entry> entries) {
  final tiff = <int>[0x4d, 0x4d, 0x00, 0x2a];
  _u32(tiff, 8);

  final ifd = <int>[];
  _u16(ifd, entries.length);

  // Where out-of-line values start, as an offset from the TIFF header.
  var pool = 8 + 2 + entries.length * 12 + 4;
  final extra = <int>[];

  for (final entry in entries) {
    _u16(ifd, entry.tag);
    _u16(ifd, entry.type);
    _u32(ifd, entry.count);
    if (entry.data.length <= 4) {
      ifd.addAll(entry.data);
      ifd.addAll(List<int>.filled(4 - entry.data.length, 0));
    } else {
      _u32(ifd, pool);
      extra.addAll(entry.data);
      pool += entry.data.length;
    }
  }
  _u32(ifd, 0);

  final payload = <int>[
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // 'Exif\0\0'
    ...tiff,
    ...ifd,
    ...extra,
  ];

  final segment = <int>[0xff, 0xe1];
  _u16(segment, payload.length + 2);
  return <int>[...segment, ...payload];
}

/// A JPEG header: SOI, an optional EXIF segment, an optional APP14 Adobe
/// segment, then SOF0 and EOI. Enough for the metadata reader, not for a decoder.
Uint8List jpeg({
  List<Entry> entries = const <Entry>[],
  int components = 3,
  int width = 16,
  int height = 8,
  bool adobeMarker = false,
  int adobeTransform = 1,
  int adobeLength = 14,
  bool exif = true,
}) {
  final out = <int>[0xff, 0xd8];

  if (exif) {
    out.addAll(exifSegment(entries));
  }

  if (adobeMarker) {
    final payload = <int>[
      0x41, 0x64, 0x6f, 0x62, 0x65, // 'Adobe'
      0x00, 0x64, // version
      0x00, 0x00, 0x00, 0x00, // flags
      adobeTransform,
    ];
    while (payload.length + 2 < adobeLength) {
      payload.add(0);
    }
    out.addAll(<int>[0xff, 0xee]);
    _u16(out, adobeLength);
    out.addAll(payload.take(adobeLength - 2));
  }

  final sof = <int>[8];
  _u16(sof, height);
  _u16(sof, width);
  sof.add(components);
  for (var c = 0; c < components; c++) {
    sof.addAll(<int>[c + 1, 0x11, 0]);
  }
  out.addAll(<int>[0xff, 0xc0]);
  _u16(out, sof.length + 2);
  out.addAll(sof);

  out.addAll(<int>[0xff, 0xd9]);
  return Uint8List.fromList(out);
}

/// A JPEG a decoder will actually accept, carrying [entries] as its EXIF.
///
/// The header-only files above are enough for PdfJpegInfo but not for
/// im.findDecoderForData, which pw.MemoryImage goes through.
Uint8List decodableJpeg(List<Entry> entries) {
  final encoded = im.encodeJpg(im.Image(width: 16, height: 8), quality: 40);

  return Uint8List.fromList(<int>[
    encoded[0],
    encoded[1], // SOI
    ...exifSegment(entries),
    ...encoded.sublist(2),
  ]);
}

/// A SHORT entry holding one value.
Entry shortEntry(int tag, int value, {int count = 1}) =>
    Entry(tag, 3, count, <int>[(value >> 8) & 0xff, value & 0xff]);

const orientationTag = 0x0112;
const xResolutionTag = 0x011a;
const exifVersionTag = 0x9000;
const pixelXDimensionTag = 0xa002;

void main() {
  group('a hostile value count', () {
    // numValues came straight off the wire and was used as the allocation size
    // and the loop bound for every typed list, with no check against the file
    // length: a 60-byte JPEG could ask for 32 GiB or walk off the end.
    for (final type in <int>[1, 2, 3, 4, 5, 7, 9, 10, 11, 12]) {
      for (final count in <int>[0xffffffff, 0x20000000, 0]) {
        test('type $type count $count allocates nothing', () {
          final bytes = jpeg(
            entries: <Entry>[
              Entry(orientationTag, type, count, <int>[0, 8]),
            ],
          );
          expect(bytes.length, lessThan(100));

          final watch = Stopwatch()..start();
          expect(() => PdfJpegInfo(bytes), returnsNormally);
          expect(watch.elapsedMilliseconds, lessThan(1000));
        });
      }
    }

    test('a value offset outside the file reads nothing', () {
      final bytes = jpeg(
        entries: <Entry>[
          Entry(orientationTag, 3, 4, <int>[0x7f, 0xff, 0xff, 0xff]),
        ],
      );

      expect(() => PdfJpegInfo(bytes), returnsNormally);
      expect(PdfJpegInfo(bytes).tags![PdfExifTag.Orientation], isNull);
    });

    test('an unbounded IFD entry count stops at the buffer end', () {
      // The entry count is a uint16 read before any of the entries exist.
      final bytes = jpeg(entries: <Entry>[shortEntry(orientationTag, 3)]);
      // Overwrite the entry count with 0xffff.
      final patched = Uint8List.fromList(bytes);
      final ifd =
          patched.indexOf(0x45) + 6 + 8; // after 'Exif\0\0' and the TIFF
      patched[ifd] = 0xff;
      patched[ifd + 1] = 0xff;

      expect(() => PdfJpegInfo(patched), returnsNormally);
    });
  });

  group('a malformed Orientation', () {
    // orientation computed `tags[Orientation] - 1` on a dynamic value, and
    // _readTagValue returns an int, a String, a double, a typed list, a list of
    // pairs or null depending on type and count. Only the int case worked: the
    // rest threw "Class 'Uint16List' has no instance method '-'" out of
    // PdfImage.jpeg, aborting the whole document.
    final cases = <String, Uint8List>{
      'SHORT count 2': jpeg(
        entries: <Entry>[shortEntry(orientationTag, 6, count: 2)],
      ),
      'BYTE count 2': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 1, 2, <int>[0x06, 0x01]),
        ],
      ),
      'ASCII': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 2, 2, <int>[0x36, 0x00]),
        ],
      ),
      'FLOAT': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 11, 1, <int>[0x40, 0xc0, 0x00, 0x00]),
        ],
      ),
      'DOUBLE': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 12, 1, <int>[0x40, 0x18, 0, 0, 0, 0, 0, 0]),
        ],
      ),
      'RATIONAL': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 5, 1, <int>[0, 0, 0, 6, 0, 0, 0, 1]),
        ],
      ),
      'unhandled type 42': jpeg(
        entries: <Entry>[
          Entry(orientationTag, 42, 1, <int>[0x06]),
        ],
      ),
      'out of range 99': jpeg(entries: <Entry>[shortEntry(orientationTag, 99)]),
      'zero': jpeg(entries: <Entry>[shortEntry(orientationTag, 0)]),
    };

    cases.forEach((String name, Uint8List bytes) {
      test('of shape $name does not throw', () {
        late PdfImageOrientation orientation;
        expect(
          () => orientation = PdfJpegInfo(bytes).orientation,
          returnsNormally,
        );
        expect(PdfImageOrientation.values, contains(orientation));
      });

      test('of shape $name embeds without aborting the document', () async {
        expect(
          () => PdfImage.jpeg(PdfDocument(), image: bytes),
          returnsNormally,
        );
      });
    });

    test('of an integer array resolves to its first element', () {
      final bytes = jpeg(
        entries: <Entry>[shortEntry(orientationTag, 6, count: 2)],
      );
      expect(PdfJpegInfo(bytes).orientation, PdfImageOrientation.rightTop);
    });

    test('of ASCII digits resolves to that value', () {
      for (var value = 1; value <= 8; value++) {
        final bytes = jpeg(
          entries: <Entry>[
            Entry(orientationTag, 2, 2, <int>[0x30 + value, 0x00]),
          ],
        );
        expect(
          PdfJpegInfo(bytes).orientation,
          PdfImageOrientation.values[value - 1],
          reason: 'ASCII $value',
        );
      }
    });

    test('out of the 1..8 range falls back to topLeft', () {
      for (final value in <int>[0, 9, 99, 0xffff]) {
        expect(
          PdfJpegInfo(
            jpeg(entries: <Entry>[shortEntry(orientationTag, value)]),
          ).orientation,
          PdfImageOrientation.topLeft,
          reason: '$value',
        );
      }
    });
  });

  test('a document with a malformed Orientation still saves', () async {
    // The accessor threw out of PdfImage.jpeg, which aborted the whole build.
    for (final entries in <List<Entry>>[
      <Entry>[shortEntry(orientationTag, 6, count: 2)],
      <Entry>[
        Entry(orientationTag, 1, 2, <int>[0x06, 0x01]),
      ],
      <Entry>[
        Entry(orientationTag, 2, 2, <int>[0x36, 0x00]),
      ],
      <Entry>[
        Entry(orientationTag, 11, 1, <int>[0x40, 0xc0, 0x00, 0x00]),
      ],
      <Entry>[
        Entry(orientationTag, 42, 1, <int>[0x06]),
      ],
    ]) {
      final bytes = decodableJpeg(entries);
      final document = pw.Document();
      document.addPage(
        pw.Page(build: (pw.Context context) => pw.Image(pw.MemoryImage(bytes))),
      );

      expect(await document.save(), isNotEmpty);
    }
  });

  test('a well-formed Orientation maps as it always has', () {
    for (var value = 1; value <= 8; value++) {
      final info = PdfJpegInfo(
        jpeg(entries: <Entry>[shortEntry(orientationTag, value)]),
      );
      expect(info.orientation, PdfImageOrientation.values[value - 1]);
      expect(info.width, 16);
      expect(info.height, 8);
    }
  });

  test('the other accessors never throw either', () {
    // Every one of these reads a dynamic tag value and assumed its shape.
    final bytes = jpeg(
      entries: <Entry>[
        Entry(exifVersionTag, 3, 1, <int>[0x00, 0x01]),
        Entry(xResolutionTag, 2, 2, <int>[0x37, 0x00]),
        Entry(pixelXDimensionTag, 11, 1, <int>[0x42, 0x48, 0, 0]),
      ],
    );
    final info = PdfJpegInfo(bytes);

    expect(() => info.exifVersion, returnsNormally);
    expect(() => info.flashpixVersion, returnsNormally);
    expect(() => info.xResolution, returnsNormally);
    expect(() => info.yResolution, returnsNormally);
    expect(() => info.pixelXDimension, returnsNormally);
    expect(() => info.pixelYDimension, returnsNormally);
    expect(() => info.toString(), returnsNormally);
  });

  test('a well-formed resolution still divides its two longs', () {
    final bytes = jpeg(
      entries: <Entry>[
        Entry(xResolutionTag, 5, 1, <int>[0, 0, 0, 72, 0, 0, 0, 1]),
      ],
    );

    expect(PdfJpegInfo(bytes).xResolution, 72.0);
  });

  group('a truncated JPEG', () {
    test('never throws anything but a PdfException', () {
      final whole = jpeg(
        entries: <Entry>[
          shortEntry(orientationTag, 6),
          Entry(xResolutionTag, 5, 1, <int>[0, 0, 0, 72, 0, 0, 0, 1]),
        ],
      );

      var parsed = 0;
      for (var length = 0; length <= whole.length; length++) {
        final prefix = Uint8List.sublistView(whole, 0, length);
        try {
          PdfJpegInfo(prefix);
          parsed++;
        } on PdfException {
          // The documented failure.
        } catch (e) {
          fail('prefix of $length bytes threw ${e.runtimeType}: $e');
        }
      }

      expect(parsed, greaterThan(0), reason: 'the whole file still parses');
    });

    test('that is not a JPEG at all throws PdfException', () {
      expect(
        () => PdfJpegInfo(Uint8List.fromList(utf8.encode('not a jpeg'))),
        throwsA(isA<PdfException>()),
      );
    });
  });
}
