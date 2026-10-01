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
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:printing/printing.dart';
import 'package:printing/src/method_channel.dart';

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  test('toPng disposes the image it decoded', () async {
    // toImage() hands its image to the caller, but toPng()'s is an
    // intermediate: it used to be abandoned, so every page of every preview
    // re-raster left a full-resolution decode in engine memory.
    var created = 0;
    var disposed = 0;
    final previousCreate = ui.Image.onCreate;
    final previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (ui.Image image) => created++;
    ui.Image.onDispose = (ui.Image image) => disposed++;
    addTearDown(() {
      ui.Image.onCreate = previousCreate;
      ui.Image.onDispose = previousDispose;
    });

    final raster = PdfRaster(
      4,
      4,
      Uint8List.fromList(List<int>.filled(4 * 4 * 4, 0xff)),
    );

    for (var i = 0; i < 5; i++) {
      await raster.toPng();
    }

    expect(created, 5);
    expect(disposed, created, reason: 'nothing is left in engine memory');
  });

  test('toImage hands its image to the caller', () async {
    final raster = PdfRaster(
      4,
      4,
      Uint8List.fromList(List<int>.filled(4 * 4 * 4, 0xff)),
    );

    final image = await raster.toImage();

    expect(image.debugDisposed, isFalse, reason: 'the caller owns this one');
    image.dispose();
  });

  test('an opaque page survives toPng', () async {
    // What the native backends now hand over. They used to return alpha 0 for
    // most of a blank page, so re-encoding it gave a black page.
    final raster = PdfRaster(
      4,
      4,
      Uint8List.fromList(List<int>.filled(4 * 4 * 4, 0xff)),
    );

    final decoded = im.decodePng(await raster.toPng());

    expect(decoded, isNotNull);
    expect(decoded!.width, 4);
    expect(decoded.height, 4);
    for (final pixel in decoded) {
      expect(
        <num>[pixel.r, pixel.g, pixel.b, pixel.a],
        <num>[255, 255, 255, 255],
        reason: 'every pixel must stay opaque white',
      );
    }
  });

  test('PdfRaster', () async {
    final raster = PdfRaster(
      10,
      10,
      Uint8List.fromList(List<int>.filled(10 * 10 * 4, 0)),
    );
    expect(raster.toString(), 'Image 10x10 400 bytes');
    expect(await raster.toImage(), isA<ui.Image>());
    expect(await raster.toPng(), isA<Uint8List>());
  });

  testWidgets('PdfRasterImage', (WidgetTester tester) async {
    final raster = PdfRaster(
      10,
      10,
      Uint8List.fromList(List<int>.filled(10 * 10 * 4, 0)),
    );

    await tester.pumpWidget(Image(image: PdfRasterImage(raster)));
    await tester.pumpAndSettle();
  });

  group('the raster stream', () {
    const channel = MethodChannel('net.nfet.printing');
    const codec = StandardMethodCodec();
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<ByteData?> fromPlatform(String method, Object arguments) async {
      ByteData? reply;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            codec.encodeMethodCall(MethodCall(method, arguments)),
            (ByteData? data) => reply = data,
          );
      return reply;
    }

    int job() => calls.last.arguments['job'] as int;

    Future<void> sendPage(int index) =>
        fromPlatform('onPageRasterized', <String, dynamic>{
          'job': job(),
          'width': 1,
          'height': 1,
          // One pixel, distinct per page, so order is observable.
          'image': Uint8List.fromList(<int>[index, 0, 0, 0xff]),
        });

    Future<ByteData?> endRaster({String? error}) => fromPlatform(
      'onPageRasterEnd',
      <String, dynamic>{'job': job(), 'error': error},
    );

    test('pages delivered after the rasterPdf reply still arrive', () async {
      // The reply used to mean 'the whole document has been rendered', because
      // the desktop backends ran the loop inline in the method-call handler. It
      // only means the job has started.
      final received = <int>[];
      final done = Completer<void>();

      Printing.raster(Uint8List(0)).listen(
        (PdfRaster page) => received.add(page.pixels.first),
        onDone: done.complete,
      );
      await pumpEventQueue();
      expect(calls, hasLength(1), reason: 'the request went out');

      for (var i = 0; i < 3; i++) {
        await sendPage(i);
      }
      await endRaster();
      await done.future;

      expect(received, <int>[0, 1, 2], reason: 'in order, none dropped');
    });

    test('a second end message is ignored', () async {
      var closes = 0;
      Printing.raster(Uint8List(0)).listen(null, onDone: () => closes++);
      await pumpEventQueue();

      await sendPage(0);
      await endRaster();
      await pumpEventQueue();

      // A backend that reports twice must not raise 'Bad state'.
      final reply = await endRaster();
      await pumpEventQueue();

      expect(closes, 1);
      expect(() => codec.decodeEnvelope(reply!), returnsNormally);
    });

    test('an error ends the stream with that error', () async {
      // What a page too large to raster now reports, instead of taking the
      // whole process down with an access violation.
      Object? error;
      var closed = false;

      Printing.raster(Uint8List(0)).listen(
        null,
        onError: (Object e) => error = e,
        onDone: () => closed = true,
      );
      await pumpEventQueue();

      await endRaster(error: 'Cannot raster a page this large');
      await pumpEventQueue();

      expect(error, 'Cannot raster a page this large');
      expect(closed, isTrue);
    });

    test('an error mid-document reaches an await for loop', () async {
      // What a page whose blob cannot be read now does on web, and what a page
      // too large to rasterize does on desktop. It used to hang instead.
      final received = <int>[];
      Object? error;

      final consumed = Future<void>(() async {
        try {
          await for (final page in Printing.raster(Uint8List(0))) {
            received.add(page.pixels.first);
          }
        } catch (e) {
          error = e;
        }
      });
      await pumpEventQueue();

      await sendPage(1);
      await pumpEventQueue();
      await endRaster(error: 'Unable to encode page 2');
      await consumed;

      expect(received, <int>[1], reason: 'the pages before the failure arrive');
      expect(error, 'Unable to encode page 2');
    });

    test('a raster after a failed one gets its own job', () async {
      Printing.raster(Uint8List(0)).listen(null, onError: (Object _) {});
      await pumpEventQueue();
      final first = job();
      await endRaster(error: 'nope');
      await pumpEventQueue();

      Printing.raster(Uint8List(0)).listen(null, onError: (Object _) {});
      await pumpEventQueue();
      final second = job();

      expect(second, isNot(first));
      expect(MethodChannelPrinting.pendingJobs, 1);

      await endRaster(error: 'nope');
      await pumpEventQueue();
      expect(MethodChannelPrinting.pendingJobs, 0, reason: 'nothing left over');
    });
  });
}
