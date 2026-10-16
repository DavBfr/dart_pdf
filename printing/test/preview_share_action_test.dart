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

import 'dart:async';

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

  testWidgets('sharing calls onShared, not onPrinted', (tester) async {
    var printed = 0;
    var shared = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreview(
          dpi: 72,
          build: (PdfPageFormat format) async => Uint8List(0),
          onPrinted: (BuildContext context) => printed++,
          onShared: (BuildContext context) => shared++,
        ),
      ),
    );
    await finishRaster(tester);

    await tester.tap(find.byIcon(Icons.share));
    await settle(tester);

    expect(calls.map((MethodCall c) => c.method), contains('sharePdf'));
    expect(shared, 1, reason: 'onShared must be the callback for sharing');
    expect(printed, 0, reason: 'onPrinted belongs to the print button');
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('sharing still works with no callback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreview(
          dpi: 72,
          build: (PdfPageFormat format) async => Uint8List(0),
        ),
      ),
    );
    await finishRaster(tester);

    await tester.tap(find.byIcon(Icons.share));
    await settle(tester);

    expect(calls.map((MethodCall c) => c.method), contains('sharePdf'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a rebuild during the share does not break the anchor', (
    tester,
  ) async {
    final gate = Completer<Uint8List>();
    var shared = 0;
    final errors = <Object>[];
    late void Function() rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            rebuild = () => setState(() {});
            return PdfPreview(
              dpi: 72,
              build: (PdfPageFormat format) => gate.future,
              onShared: (BuildContext context) => shared++,
            );
          },
        ),
      ),
    );
    await settle(tester);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) =>
        errors.add(details.exception);

    await tester.tap(find.byIcon(Icons.share));
    await tester.pump();

    // Any rebuild of the preview replaces the share action, and with it the
    // per-widget GlobalKey the action used to read after its await.
    rebuild();
    await tester.pump();

    gate.complete(Uint8List(0));
    await finishRaster(tester);
    FlutterError.onError = previousOnError;

    expect(
      errors,
      isEmpty,
      reason: 'the anchor must not be read after a rebuild',
    );
    expect(calls.map((MethodCall c) => c.method), contains('sharePdf'));
    expect(shared, 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a failing document build reports through onShareError', (
    tester,
  ) async {
    final reported = <Object>[];
    final errors = <Object>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PdfPreview(
          dpi: 72,
          build: (PdfPageFormat format) =>
              Future<Uint8List>.error(Exception('boom')),
          onShareError: (BuildContext context, dynamic error) =>
              reported.add(error as Object),
        ),
      ),
    );
    await settle(tester);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) =>
        errors.add(details.exception);

    await tester.tap(find.byIcon(Icons.share));
    await settle(tester);
    FlutterError.onError = previousOnError;

    expect(reported, hasLength(1), reason: 'onShareError must be called');
    expect(
      errors,
      hasLength(1),
      reason: 'the failure is also reported as a FlutterError',
    );
    expect(
      calls.map((MethodCall c) => c.method),
      isNot(contains('sharePdf')),
      reason: 'the document never built',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
