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
import 'package:printing/printing.dart';
import 'package:printing/src/preview/page.dart';

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

  setUp(() {
    rasterJobs = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          switch (call.method) {
            case 'printingInfo':
              return <String, dynamic>{'canRaster': true};
            case 'rasterPdf':
              rasterJobs.add(call.arguments['job'] as int);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Widget host(LayoutCallback build) =>
      MaterialApp(home: PdfPreviewCustom(dpi: 72, build: build));

  // A page arriving from the platform side, as `onPageRasterized` delivers it.
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

  // Lets the 300ms preview debounce elapse and the raster request go out.
  Future<void> startRaster(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  // `page.toPng()` decodes through the engine, which only makes progress on a
  // real event loop — `pump()` alone leaves it pending forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  testWidgets('disposing during a re-raster does not throw', (tester) async {
    await tester.pumpWidget(host((_) async => Uint8List(0)));
    await startRaster(tester);
    expect(rasterJobs, hasLength(1));

    // First pass populates `pages`, so the next one takes the branch that
    // writes into it by index instead of appending.
    await sendPage();
    await settle(tester);
    final ended = endRaster();
    await settle(tester);
    await ended;

    // Also the precondition for the rest of the test: if the page never
    // rendered, `pages` is empty, the branch below is the appending one, and
    // the assertion at the end would hold vacuously.
    expect(find.byType(Image), findsOneWidget);

    // A new `build` closure is never == the old one, so this re-rasters.
    await tester.pumpWidget(host((_) async => Uint8List(0)));
    await startRaster(tester);
    expect(rasterJobs, hasLength(2));

    // Deliver a page and unmount before the rasterizer resumes: it is
    // suspended inside `page.toPng()` at that moment, and `dispose()` clears
    // the very list its continuation is about to write into.
    await sendPage();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the scroll controller is disposed with the preview', (
    tester,
  ) async {
    final key = GlobalKey<PdfPreviewCustomState>();

    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreviewCustom(
          key: key,
          dpi: 72,
          build: (_) async => Uint8List(0),
        ),
      ),
    );
    await startRaster(tester);
    await sendPage();
    await settle(tester);
    final ended = endRaster();
    await settle(tester);
    await ended;

    // The state creates this, so the state has to dispose it. Every mount and
    // unmount used to leak one, with its listener list.
    final controller = key.currentState!.scrollController;
    expect(() => controller.addListener(() {}), returnsNormally);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);

    expect(() => controller.addListener(() {}), throwsFlutterError);
  });

  testWidgets('unmounting with a pending scroll restore does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(host((_) async => Uint8List(0)));
    await startRaster(tester);
    await sendPage();
    await settle(tester);
    final ended = endRaster();
    await settle(tester);
    await ended;

    // Zoom in and out. Coming out of the zoom schedules a Timer.run that jumps
    // the scroll position; unmounting before it runs used to reach a disposed
    // controller.
    final page = find.byType(PdfPreviewPage);
    expect(page, findsOneWidget);
    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(page);
    await tester.pumpAndSettle();

    final zoomed = find.byType(InteractiveViewer);
    expect(zoomed, findsOneWidget);
    await tester.tap(zoomed);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(zoomed);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    // The clock has to be elapsed for the pending timers to fire at all:
    // pump() with no duration only flushes microtasks. This is where the
    // scroll restore runs, with nothing left to restore onto.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(tester.takeException(), isNull);
  });
}
