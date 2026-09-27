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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late int shareResult;
  late List<int> rasterJobs;

  setUp(() {
    calls = <MethodCall>[];
    shareResult = 1;
    rasterJobs = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          switch (call.method) {
            case 'printingInfo':
              return <String, dynamic>{
                'canPrint': true,
                'canShare': true,
                'canRaster': true,
              };
            case 'sharePdf':
              // The channel carries an int, not a bool.
              return shareResult;
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

  Future<void> fromPlatform(String method, Object arguments) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            null,
          );

  // The preview needs a few real event-loop turns to read the platform
  // capabilities, decode the rasterized page and lay the action bar out.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  /// Answer the preview's raster request, so its `await for` terminates.
  ///
  /// Without this the preview waits on an open stream for ever and the test
  /// times out rather than reaching the action bar.
  Future<void> finishRaster(WidgetTester tester) async {
    // Let the 300ms preview debounce elapse so the request goes out.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    if (rasterJobs.isEmpty) {
      return;
    }
    await fromPlatform('onPageRasterized', <String, dynamic>{
      'job': rasterJobs.last,
      'width': 1,
      'height': 1,
      'image': Uint8List.fromList(<int>[0xff, 0x00, 0x00, 0xff]),
    });
    await fromPlatform('onPageRasterEnd', <String, dynamic>{
      'job': rasterJobs.last,
      'error': null,
    });
    await settle(tester);
  }

  testWidgets('a roll format keeps its width and gains a real height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreview(
          dpi: 72,
          initialPageFormat: PdfPageFormat.roll80,
          build: (PdfPageFormat format) async => Uint8List(0),
        ),
      ),
    );
    await finishRaster(tester);

    await tester.tap(find.byIcon(Icons.print));
    await settle(tester);

    final call = calls.lastWhere((MethodCall c) => c.method == 'printPdf');
    expect(
      call.arguments['width'],
      closeTo(80 * PdfPageFormat.mm, 1e-6),
      reason: 'the requested roll width must be kept exactly',
    );
    final height = call.arguments['height'] as double;
    expect(height.isFinite, isTrue);
    expect(
      height,
      greaterThan(0),
      reason: 'the height comes from the rasterized page',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
