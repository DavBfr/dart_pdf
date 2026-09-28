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
import 'package:printing/src/preview/controller.dart';

const _channel = MethodChannel('net.nfet.printing');
const _codec = StandardMethodCodec();

Future<void> _fromPlatform(String method, Object arguments) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          _codec.encodeMethodCall(MethodCall(method, arguments)),
          null,
        );

Future<Uint8List> _build(PdfPageFormat format) async => Uint8List(0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<Object?, Object?>> rasterCalls;

  setUp(() {
    rasterCalls = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          switch (call.method) {
            case 'printingInfo':
              return <String, dynamic>{
                'canPrint': true,
                'canShare': true,
                'canRaster': true,
              };
            case 'rasterPdf':
              rasterCalls.add(call.arguments as Map<Object?, Object?>);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> endRaster() => _fromPlatform(
    'onPageRasterEnd',
    <String, dynamic>{'job': rasterCalls.last['job'], 'error': null},
  );

  /// Let the debounce elapse, then close the stream the request opened.
  Future<void> runRaster(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    if (rasterCalls.isEmpty) {
      return;
    }
    final ended = endRaster();
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await ended;
  }

  group('a raster input change', () {
    Widget host({List<int>? pages, double? dpi, double? maxPageWidth}) =>
        MaterialApp(
          home: SizedBox(
            height: 600,
            // A stable tear-off, so the identity of `build` cannot be what
            // triggers the re-raster.
            child: PdfPreviewCustom(
              build: _build,
              pages: pages,
              dpi: dpi,
              maxPageWidth: maxPageWidth,
            ),
          ),
        );

    testWidgets('a new page filter re-rasters, with the new filter', (
      tester,
    ) async {
      await tester.pumpWidget(host(pages: <int>[0]));
      await runRaster(tester);
      expect(rasterCalls, hasLength(1));
      expect(rasterCalls.last['pages'], <int>[0]);

      await tester.pumpWidget(host(pages: <int>[1]));
      await runRaster(tester);

      expect(rasterCalls, hasLength(2));
      expect(rasterCalls.last['pages'], <int>[1]);
    });

    testWidgets('an equal page filter does not', (tester) async {
      await tester.pumpWidget(host(pages: <int>[1]));
      await runRaster(tester);
      expect(rasterCalls, hasLength(1));

      // A fresh list literal with the same contents. Compared by identity this
      // would re-raster on every single rebuild.
      await tester.pumpWidget(host(pages: <int>[1]));
      await runRaster(tester);

      expect(rasterCalls, hasLength(1));
    });

    testWidgets('a new dpi re-rasters at that scale', (tester) async {
      await tester.pumpWidget(host());
      await runRaster(tester);
      expect(rasterCalls, hasLength(1));

      await tester.pumpWidget(host(dpi: 300));
      await runRaster(tester);

      expect(rasterCalls, hasLength(2));
      expect(rasterCalls.last['scale'], 300 / PdfPageFormat.inch);

      // And back again.
      await tester.pumpWidget(host());
      await runRaster(tester);
      expect(rasterCalls, hasLength(3));
      expect(rasterCalls.last['scale'], isNot(300 / PdfPageFormat.inch));
    });

    testWidgets('a new max width re-rasters only without a forced dpi', (
      tester,
    ) async {
      await tester.pumpWidget(host(maxPageWidth: 400));
      await runRaster(tester);
      expect(rasterCalls, hasLength(1));

      await tester.pumpWidget(host(maxPageWidth: 200));
      await runRaster(tester);
      expect(rasterCalls, hasLength(2));
      expect(rasterCalls.last['scale'], lessThan(rasterCalls.first['scale']!));

      // With the dpi forced, the width cannot move the resolution.
      await tester.pumpWidget(host(dpi: 72, maxPageWidth: 200));
      await runRaster(tester);
      expect(rasterCalls, hasLength(3));

      await tester.pumpWidget(host(dpi: 72, maxPageWidth: 100));
      await runRaster(tester);
      expect(rasterCalls, hasLength(3));
    });

    testWidgets('a rebuild that changes nothing does not re-raster', (
      tester,
    ) async {
      await tester.pumpWidget(host(pages: <int>[0], dpi: 72));
      await runRaster(tester);
      expect(rasterCalls, hasLength(1));

      await tester.pumpWidget(host(pages: <int>[0], dpi: 72));
      await runRaster(tester);

      expect(rasterCalls, hasLength(1));
    });
  });

  group('PdfPreviewData', () {
    late List<PdfPageFormat> formatChanges;
    late List<PdfPreviewData> seen;

    setUp(() {
      formatChanges = <PdfPageFormat>[];
      seen = <PdfPreviewData>[];
    });

    final key = GlobalKey<PdfPreviewState>();

    Widget host() => MaterialApp(
      home: SizedBox(
        height: 600,
        child: PdfPreview(
          key: key,
          dpi: 72,
          // A closure literal, so every pump is a qualifying rebuild that
          // replaces the PdfPreviewData.
          build: (PdfPageFormat format) async => Uint8List(0),
          onPageFormatChanged: formatChanges.add,
        ),
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(host());
      await runRaster(tester);
      final data = key.currentState!.previewData;
      if (!seen.contains(data)) {
        seen.add(data);
      }
    }

    testWidgets('keeps reporting page format changes across rebuilds', (
      tester,
    ) async {
      await pump(tester);

      // Two orientation toggles, with a parent rebuild in between. The listener
      // used to be registered once in initState on an object that
      // didUpdateWidget then replaced, so everything after the first rebuild
      // was silently dropped.
      key.currentState!.previewData.horizontal = true;
      await tester.pump();
      expect(formatChanges, hasLength(1));

      await pump(tester);

      key.currentState!.previewData.horizontal = false;
      await tester.pump();

      expect(formatChanges, hasLength(2));
    });

    testWidgets('carries the selected format across a rebuild', (tester) async {
      await pump(tester);

      key.currentState!.previewData.pageFormat = PdfPageFormat.a6;
      await tester.pump();
      final reported = formatChanges.length;

      await pump(tester);

      expect(key.currentState!.previewData.pageFormat, PdfPageFormat.a6);
      expect(
        formatChanges,
        hasLength(reported),
        reason: 'the swap itself is not a format change',
      );
    });

    testWidgets('disposes every instance it replaces', (tester) async {
      for (var i = 0; i < 3; i++) {
        await pump(tester);
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'the rebuilds must actually have replaced it',
      );

      await tester.pumpWidget(const SizedBox.shrink());

      for (final data in seen) {
        expect(
          () => data.addListener(() {}),
          throwsFlutterError,
          reason: 'every replaced instance must be disposed',
        );
      }
    });
  });
}
