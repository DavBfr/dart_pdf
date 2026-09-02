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
}
