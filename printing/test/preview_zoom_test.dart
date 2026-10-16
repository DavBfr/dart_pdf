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
  late List<bool> zoomChanges;

  setUp(() {
    rasterJobs = <int>[];
    zoomChanges = <bool>[];
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

  final key = GlobalKey<PdfPreviewCustomState>();

  // The re-raster is driven by a resize, which is the reported scenario -
  // rotate, resize or change the text scale while a page is zoomed - and which
  // does not reset the zoom the way a new build closure does.
  Widget host({double width = 800}) => MediaQuery(
    data: MediaQueryData(size: Size(width, 600)),
    child: MaterialApp(
      home: SizedBox(
        height: 600,
        child: PdfPreviewCustom(
          key: key,
          onZoomChanged: zoomChanges.add,
          build: _build,
        ),
      ),
    ),
  );

  /// A wide, short page, so several of them are on screen at once and the last
  /// can actually be tapped.
  Future<void> sendPage() =>
      _fromPlatform('onPageRasterized', <String, dynamic>{
        'job': rasterJobs.last,
        'width': 8,
        'height': 1,
        'image': Uint8List.fromList(<int>[
          for (var i = 0; i < 8; i++) ...<int>[0xff, 0x00, 0x00, 0xff],
        ]),
      });

  Future<void> endRaster() => _fromPlatform(
    'onPageRasterEnd',
    <String, dynamic>{'job': rasterJobs.last, 'error': null},
  );

  Future<void> startRaster(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  Future<void> deliver(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await sendPage();
      await settle(tester);
    }
    final ended = endRaster();
    await settle(tester);
    await ended;
    await settle(tester);
  }

  /// Double-tap the last page to zoom it, as a user would.
  Future<void> zoomLastPage(WidgetTester tester, {required int index}) async {
    final pages = find.byType(PdfPreviewPage);
    expect(pages, findsNWidgets(index + 1));
    await tester.tap(pages.last);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(pages.last);
    await tester.pumpAndSettle();

    // The whole point of the test is that this index outlives a raster that
    // makes it invalid.
    expect(key.currentState!.preview, index);
  }

  testWidgets('a zoomed page survives a shrinking re-raster', (tester) async {
    await tester.pumpWidget(host());
    await startRaster(tester);
    await deliver(tester, 2);

    await zoomLastPage(tester, index: 1);
    expect(zoomChanges, <bool>[true]);

    // A re-raster that yields fewer pages. `preview` used to keep indexing the
    // old list, so build threw RangeError: a red error widget, and a preview
    // the user could not get out of.
    await tester.pumpWidget(host(width: 600));
    await startRaster(tester);
    await deliver(tester, 1);

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(key.currentState!.pageCount, 1);
  });

  testWidgets('a re-raster to no pages leaves the zoom', (tester) async {
    await tester.pumpWidget(host());
    await startRaster(tester);
    await deliver(tester, 2);

    await zoomLastPage(tester, index: 1);
    expect(zoomChanges, <bool>[true]);

    // An empty document: any zoomed index is out of range.
    await tester.pumpWidget(host(width: 600));
    await startRaster(tester);
    await deliver(tester, 0);

    expect(tester.takeException(), isNull);
    expect(key.currentState!.pageCount, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(zoomChanges, <bool>[
      true,
      false,
    ], reason: 'the zoom really ended, so the callback is owed one call');
  });

  testWidgets('a re-raster that keeps the page count keeps the zoom', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await startRaster(tester);
    await deliver(tester, 2);

    await zoomLastPage(tester, index: 1);
    expect(zoomChanges, <bool>[true]);

    await tester.pumpWidget(host(width: 600));
    await startRaster(tester);
    await deliver(tester, 2);

    expect(tester.takeException(), isNull);
    expect(zoomChanges, <bool>[
      true,
    ], reason: 'the zoom state did not change, so nothing is reported');
    // Still zoomed: one page on screen, not a list.
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}

Future<Uint8List> _build(_) async => Uint8List(0);
