/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/object_base.dart' show PdfObjectBase;
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  group('streaming document output', () {
    for (final pageMode in PdfPageMode.values) {
      for (final version in PdfVersion.values) {
        for (final compress in <bool>[false, true]) {
          for (final balance in <bool>[false, true]) {
            test('${pageMode.name}, ${version.name}, compress=$compress, '
                'balance=$balance', () async {
              final document = _buildDocument(
                pageMode: pageMode,
                version: version,
                compress: compress,
              );
              final streamed = _RecordingPdfStream();

              await document.write(streamed, enableEventLoopBalancing: balance);
              final saved = await document.save(
                enableEventLoopBalancing: balance,
              );

              expect(streamed.output(), orderedEquals(saved));
              expect(streamed.offset, saved.length);
              expect(streamed.writeCount, greaterThan(1));
              _expectPdfEnvelope(streamed.output(), version);
              _expectPageMode(streamed.output(), pageMode);
            });
          }
        }
      }
    }

    test('does not require the destination to materialize output', () async {
      final document = _buildDocument(
        version: PdfVersion.pdf_1_5,
        compress: true,
      );
      final output = _NonMaterializingPdfStream();

      await document.write(output, enableEventLoopBalancing: true);

      expect(output.offset, greaterThan(100));
      expect(output.startsWithPdfHeader, isTrue);
      expect(output.endsWithPdfTrailer, isTrue);
      expect(output.outputCalls, 0);
    });

    test('supports verbose output patching', () async {
      final document = _buildDocument(
        version: PdfVersion.pdf_1_4,
        compress: false,
        verbose: true,
      );
      final output = _RecordingPdfStream();

      await document.write(output);

      expect(output.patchCount, greaterThan(0));
      _expectPdfEnvelope(output.output(), PdfVersion.pdf_1_4);
      expect(latin1.decode(output.output()), contains('Verbose dart_pdf'));
    });

    test('can write an empty document', () async {
      final document = pw.Document();
      final output = _RecordingPdfStream();

      await document.write(output);

      _expectPdfEnvelope(output.output(), PdfVersion.pdf_1_5);
    });

    test('prevents page mutation after write', () async {
      final document = _buildDocument(
        version: PdfVersion.pdf_1_5,
        compress: true,
      );
      await document.write(_RecordingPdfStream());

      expect(
        () => document.addPage(pw.Page(build: (_) => pw.Text('late'))),
        throwsA(isA<AssertionError>()),
      );
    });

    test('propagates destination write failures', () async {
      final document = _buildDocument(
        version: PdfVersion.pdf_1_5,
        compress: false,
      );

      await expectLater(
        document.write(_FailingPdfStream(failAfter: 64)),
        throwsA(isA<StateError>()),
      );
    });

    test('uses a custom deflate callback in streamed mode', () async {
      var deflateCalls = 0;
      final document = pw.Document(
        deflate: (bytes) {
          deflateCalls++;
          return bytes;
        },
      )..addPage(pw.Page(build: (_) => pw.Text('custom deflate')));

      await document.write(_RecordingPdfStream());

      expect(deflateCalls, greaterThan(0));
    });
  });

  group('streamed JPEG images', () {
    test('remain lazy and write encoded bytes in chunks', () async {
      final jpeg = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 7, height: 5), quality: 70),
      );
      final document = PdfDocument();
      var writerCalls = 0;
      final pdfImage = PdfImage.jpegStream(
        document,
        width: 7,
        height: 5,
        length: jpeg.length,
        write: (output) {
          writerCalls++;
          final split = jpeg.length ~/ 2;
          output
            ..putBytes(jpeg.sublist(0, split))
            ..putBytes(jpeg.sublist(split));
        },
      );

      expect(writerCalls, 0);
      expect(pdfImage.buf.offset, 0);

      final output = _RecordingPdfStream();
      await document.write(output);

      expect(writerCalls, 1);
      expect(pdfImage.buf.offset, 0);
      expect(_indexOf(output.output(), jpeg), greaterThanOrEqualTo(0));
      expect(
        latin1.decode(output.output()),
        contains('/Length ${jpeg.length}'),
      );
    });

    test('supports multiple images without retaining their bytes', () async {
      final document = PdfDocument();
      var bytesWritten = 0;
      for (var i = 1; i <= 25; i++) {
        final bytes = Uint8List.fromList(<int>[0xff, 0xd8, i, 0xff, 0xd9]);
        final pdfImage = PdfImage.jpegStream(
          document,
          width: i,
          height: i + 1,
          length: bytes.length,
          write: (output) {
            bytesWritten += bytes.length;
            output.putBytes(bytes);
          },
        );
        expect(pdfImage.buf.offset, 0);
      }

      await document.write(_RecordingPdfStream());

      expect(bytesWritten, 25 * 5);
    });

    test('propagates lazy image source failures', () async {
      final document = PdfDocument();
      PdfImage.jpegStream(
        document,
        width: 1,
        height: 1,
        length: 1,
        write: (_) => throw StateError('source unavailable'),
      );

      await expectLater(
        document.write(_RecordingPdfStream()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'source unavailable',
          ),
        ),
      );
    });

    test('rejects a writer that emits the wrong byte count', () async {
      final document = PdfDocument();
      PdfImage.jpegStream(
        document,
        width: 1,
        height: 1,
        length: 3,
        write: (output) => output.putBytes(const <int>[0xff, 0xd9]),
      );

      await expectLater(
        document.write(_RecordingPdfStream()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('wrote 2 bytes; expected 3'),
          ),
        ),
      );
    });

    test('writer is invoked again for each explicit serialization', () async {
      final document = PdfDocument();
      var writerCalls = 0;
      PdfImage.jpegStream(
        document,
        width: 1,
        height: 1,
        length: 2,
        write: (output) {
          writerCalls++;
          output.putBytes(const <int>[0xff, 0xd9]);
        },
      );

      await document.write(_RecordingPdfStream());
      await document.write(_RecordingPdfStream());

      expect(writerCalls, 2);
    });

    test(
      'rejects document encryption instead of emitting invalid data',
      () async {
        final document = PdfDocument();
        document.encryption = _PassThroughEncryption(document);
        PdfImage.jpegStream(
          document,
          width: 1,
          height: 1,
          length: 2,
          write: (output) => output.putBytes(const <int>[0xff, 0xd9]),
        );

        await expectLater(
          document.write(_RecordingPdfStream()),
          throwsA(
            isA<UnsupportedError>().having(
              (error) => error.message,
              'message',
              contains('does not support encrypted documents'),
            ),
          ),
        );
      },
    );
  });

  group('PdfStream destination contract', () {
    test('tracks offsets for byte, byte-list, and string writes', () {
      final output = _RecordingPdfStream()
        ..putByte(1)
        ..putBytes(const <int>[2, 3])
        ..putString('ab');

      expect(output.offset, 5);
      expect(output.output(), orderedEquals(<int>[1, 2, 3, 97, 98]));
    });

    test('supports random-access patches without changing offset', () {
      final output = _RecordingPdfStream()
        ..putBytes(const <int>[1, 2, 3, 4])
        ..setBytes(1, const <int>[8, 9]);

      expect(output.offset, 4);
      expect(output.output(), orderedEquals(<int>[1, 8, 9, 4]));
    });

    test('copies another stream', () {
      final source = PdfStream()..putString('source');
      final output = _RecordingPdfStream()..putStream(source);

      expect(latin1.decode(output.output()), 'source');
    });
  });
}

pw.Document _buildDocument({
  PdfPageMode pageMode = PdfPageMode.none,
  required PdfVersion version,
  required bool compress,
  bool verbose = false,
}) {
  return pw.Document(
      pageMode: pageMode,
      version: version,
      compress: compress,
      verbose: verbose,
      title: 'Streaming output test',
    )
    ..addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: <pw.Widget>[
            pw.Text('First page'),
            pw.Container(width: 30, height: 20, color: PdfColors.blue),
          ],
        ),
      ),
    )
    ..addPage(
      pw.MultiPage(
        build: (_) => List<pw.Widget>.generate(
          80,
          (index) => pw.Text('Row $index: streaming mode coverage'),
        ),
      ),
    );
}

void _expectPageMode(Uint8List bytes, PdfPageMode mode) {
  const names = <PdfPageMode, String>{
    PdfPageMode.none: '/UseNone',
    PdfPageMode.outlines: '/UseOutlines',
    PdfPageMode.thumbs: '/UseThumbs',
    PdfPageMode.fullscreen: '/FullScreen',
  };
  expect(latin1.decode(bytes), contains('/PageMode${names[mode]}'));
}

void _expectPdfEnvelope(Uint8List bytes, PdfVersion version) {
  final text = latin1.decode(bytes);
  expect(
    text,
    startsWith('%PDF-${version == PdfVersion.pdf_1_4 ? '1.4' : '1.5'}'),
  );
  expect(text, endsWith('%%EOF\n'));
  expect(text, contains('startxref\n'));
  if (version == PdfVersion.pdf_1_4) {
    expect(text, contains('\nxref\n'));
  } else {
    expect(text, contains('/Type/XRef'));
  }
}

int _indexOf(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) {
    return 0;
  }
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return i;
    }
  }
  return -1;
}

class _RecordingPdfStream extends PdfStream {
  final _bytes = <int>[];

  var writeCount = 0;
  var patchCount = 0;

  @override
  int get offset => _bytes.length;

  @override
  void putByte(int s) {
    writeCount++;
    _bytes.add(s);
  }

  @override
  void putBytes(List<int> s) {
    writeCount++;
    _bytes.addAll(s);
  }

  @override
  void putStream(PdfStream s) {
    putBytes(s.output());
  }

  @override
  void setBytes(int offset, Iterable<int> iterable) {
    patchCount++;
    _bytes.setAll(offset, iterable);
  }

  @override
  Uint8List output() => Uint8List.fromList(_bytes);
}

class _NonMaterializingPdfStream extends PdfStream {
  final _firstBytes = <int>[];
  final _lastBytes = <int>[];
  var _offset = 0;

  var outputCalls = 0;

  bool get startsWithPdfHeader =>
      latin1.decode(_firstBytes).startsWith('%PDF-');

  bool get endsWithPdfTrailer => latin1.decode(_lastBytes).endsWith('%%EOF\n');

  @override
  int get offset => _offset;

  @override
  void putByte(int s) => putBytes(<int>[s]);

  @override
  void putBytes(List<int> s) {
    for (final byte in s) {
      if (_firstBytes.length < 8) {
        _firstBytes.add(byte);
      }
      _lastBytes.add(byte);
      if (_lastBytes.length > 16) {
        _lastBytes.removeAt(0);
      }
    }
    _offset += s.length;
  }

  @override
  void putStream(PdfStream s) => putBytes(s.output());

  @override
  void setBytes(int offset, Iterable<int> iterable) {
    throw UnsupportedError('This test destination is forward-only');
  }

  @override
  Uint8List output() {
    outputCalls++;
    throw UnsupportedError('No in-memory output');
  }
}

class _FailingPdfStream extends _NonMaterializingPdfStream {
  _FailingPdfStream({required this.failAfter});

  final int failAfter;

  @override
  void putBytes(List<int> s) {
    if (offset + s.length > failAfter) {
      throw StateError('destination failed');
    }
    super.putBytes(s);
  }
}

class _PassThroughEncryption extends PdfEncryption {
  _PassThroughEncryption(super.pdfDocument);

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) => input;
}
