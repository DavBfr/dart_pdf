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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

const _channel = MethodChannel('net.nfet.printing');
const _codec = StandardMethodCodec();

Future<void> _fromPlatform(String method, Object arguments) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          _codec.encodeMethodCall(MethodCall(method, arguments)),
          null,
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> rasterJobs;
  late List<double> rasterScales;
  late List<PdfPageFormat> builtFormats;

  setUp(() {
    rasterJobs = <int>[];
    rasterScales = <double>[];
    builtFormats = <PdfPageFormat>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          switch (call.method) {
            case 'printingInfo':
              return <String, dynamic>{'canRaster': true};
            case 'rasterPdf':
              rasterJobs.add(call.arguments['job'] as int);
              rasterScales.add(call.arguments['scale'] as double);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<Uint8List> build(PdfPageFormat format) async {
    builtFormats.add(format);
    return Uint8List(0);
  }

  Widget host({
    PdfPageFormat format = PdfPageFormat.a4,
    Size size = const Size(800, 600),
    EdgeInsets viewInsets = EdgeInsets.zero,
    double devicePixelRatio = 1,
  }) => MediaQuery(
    data: MediaQueryData(
      size: size,
      viewInsets: viewInsets,
      devicePixelRatio: devicePixelRatio,
    ),
    child: MaterialApp(
      home: PdfPreviewCustom(pageFormat: format, build: build),
    ),
  );

  Future<void> sendPage() =>
      _fromPlatform('onPageRasterized', <String, dynamic>{
        'job': rasterJobs.last,
        'width': 1,
        'height': 1,
        'image': Uint8List.fromList(<int>[0xff, 0x00, 0x00, 0xff]),
      });

  Future<void> endRaster() => _fromPlatform(
    'onPageRasterEnd',
    <String, dynamic>{'job': rasterJobs.last, 'error': null},
  );

  /// Let the 300ms preview debounce elapse so a queued request goes out.
  Future<void> startRaster(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  /// `page.toPng()` decodes through the engine, which only makes progress on a
  /// real event loop.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  group('a request made while one is in flight', () {
    testWidgets('is not lost', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      expect(rasterJobs, hasLength(1));
      expect(builtFormats, <PdfPageFormat>[PdfPageFormat.a4]);

      // The first job is streaming: one page delivered, no end yet.
      await sendPage();
      await settle(tester);

      // Change the format while it streams. This used to be dropped outright,
      // leaving the preview on A4 while the action bar showed Letter.
      await tester.pumpWidget(host(format: PdfPageFormat.letter));
      await startRaster(tester);
      expect(
        rasterJobs,
        hasLength(1),
        reason: 'nothing starts while the first job is still streaming',
      );

      // Let the first job finish; the queued request runs from its epilogue.
      final ended = endRaster();
      await settle(tester);
      await ended;
      await settle(tester);

      expect(rasterJobs, hasLength(2));
      expect(builtFormats.last, PdfPageFormat.letter);
    });

    testWidgets('coalesces with the others into one catch-up', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await sendPage();
      await settle(tester);

      for (final format in <PdfPageFormat>[
        PdfPageFormat.letter,
        PdfPageFormat.a5,
        PdfPageFormat.a3,
      ]) {
        await tester.pumpWidget(host(format: format));
        await startRaster(tester);
      }
      expect(rasterJobs, hasLength(1));

      final ended = endRaster();
      await settle(tester);
      await ended;
      await settle(tester);

      expect(
        rasterJobs,
        hasLength(2),
        reason: 'three refused requests are one catch-up, not three',
      );
      expect(
        builtFormats.last,
        PdfPageFormat.a3,
        reason: 'the catch-up renders the newest request',
      );
    });

    testWidgets('does not start after the preview is disposed', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await sendPage();
      await settle(tester);

      await tester.pumpWidget(host(format: PdfPageFormat.letter));
      await startRaster(tester);
      expect(rasterJobs, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      final ended = endRaster();
      await settle(tester);
      await ended;
      await settle(tester);

      expect(rasterJobs, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('with nothing in flight', () {
    testWidgets('one format change is one request', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await sendPage();
      await settle(tester);
      final ended = endRaster();
      await settle(tester);
      await ended;

      await tester.pumpWidget(host(format: PdfPageFormat.letter));
      await startRaster(tester);
      await settle(tester);

      expect(rasterJobs, hasLength(2), reason: 'not two catch-ups');
      expect(builtFormats, <PdfPageFormat>[
        PdfPageFormat.a4,
        PdfPageFormat.letter,
      ]);
    });
  });

  group('a dependency change', () {
    testWidgets('that cannot move the dpi does not re-raster', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      // Finished, so a refused request cannot be what keeps the count at one.
      await sendPage();
      await settle(tester);
      final ended = endRaster();
      await settle(tester);
      await ended;
      expect(rasterJobs, hasLength(1));
      expect(builtFormats, hasLength(1));

      // Opening the keyboard. MediaQueryData equality covers viewInsets, so
      // this used to re-run the app's whole document build and a full raster
      // pass for a byte-identical result.
      await tester.pumpWidget(
        host(viewInsets: const EdgeInsets.only(bottom: 300)),
      );
      await startRaster(tester);
      await settle(tester);

      expect(rasterJobs, hasLength(1));
      expect(builtFormats, hasLength(1));
    });

    testWidgets('that moves the dpi re-rasters at the new scale', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await sendPage();
      await settle(tester);
      final ended = endRaster();
      await settle(tester);
      await ended;
      expect(rasterScales, hasLength(1));

      await tester.pumpWidget(host(size: const Size(400, 600)));
      await startRaster(tester);
      await settle(tester);

      expect(rasterJobs, hasLength(2));
      expect(
        rasterScales.last,
        isNot(rasterScales.first),
        reason: 'a narrower page rasters at a lower resolution',
      );
    });

    testWidgets('always rasters the first time', (tester) async {
      // A width that computes a dpi of exactly 72, which is the initial value
      // of the dpi field: the gate must not read that as 'already rendered'.
      final width = PdfPageFormat.a4.width + 16;
      await tester.pumpWidget(host(size: Size(width, 600)));
      await startRaster(tester);

      expect(rasterScales, <double>[1]);
      expect(rasterJobs, hasLength(1));
    });
  });
}
