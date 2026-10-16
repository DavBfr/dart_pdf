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

  late List<int> rasterJobs;
  late int? printJob;
  late bool printed;

  setUp(() {
    rasterJobs = <int>[];
    printJob = null;
    printed = true;
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
              rasterJobs.add(call.arguments['job'] as int);
              return null;
            case 'printPdf':
              printJob = call.arguments['job'] as int;
              return 1;
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
  // capabilities and decode the rasterized page.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
  }

  /// Answer the preview's raster request, so its `await for` terminates.
  Future<void> finishRaster(WidgetTester tester) async {
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

  Future<int> tapPrint(WidgetTester tester) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreview(
          dpi: 72,
          build: (PdfPageFormat format) async => Uint8List(0),
          onPrinted: (BuildContext context) => calls++,
        ),
      ),
    );
    await finishRaster(tester);

    await tester.tap(find.byIcon(Icons.print));
    await settle(tester);

    expect(printJob, isNotNull, reason: 'the print button must reach printPdf');
    await fromPlatform('onCompleted', <String, dynamic>{
      'job': printJob,
      'completed': printed,
    });
    await settle(tester);

    return calls;
  }

  testWidgets('a printed document calls onPrinted', (tester) async {
    expect(await tapPrint(tester), 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a document that was not printed does not', (tester) async {
    // The web backend now reports false when it handed the document over as a
    // download rather than reaching a print dialog, so this path is live.
    printed = false;

    expect(await tapPrint(tester), 0);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
