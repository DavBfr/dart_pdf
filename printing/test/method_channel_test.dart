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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/method_channel.dart';

const _channel = MethodChannel('net.nfet.printing');
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPrinting impl;
  late List<MethodCall> calls;
  late Set<String> failing;

  // A platform -> Dart call, returning the reply envelope so a test can check
  // that the handler answered instead of throwing.
  Future<ByteData?> fromPlatform(String method, Object arguments) async {
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          _codec.encodeMethodCall(MethodCall(method, arguments)),
          (ByteData? data) => reply = data,
        );
    return reply;
  }

  // The job index the plugin sent with its last call of that method.
  int jobOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments['job'] as int;

  Future<ByteData?> sendPage(int job) =>
      fromPlatform('onPageRasterized', <String, dynamic>{
        'job': job,
        'width': 1,
        'height': 1,
        'image': Uint8List.fromList(<int>[0xff, 0x00, 0x00, 0xff]),
      });

  Future<ByteData?> endRaster(int job, {Object? error}) => fromPlatform(
    'onPageRasterEnd',
    <String, dynamic>{'job': job, 'error': error},
  );

  setUp(() {
    impl = MethodChannelPrinting();
    calls = <MethodCall>[];
    failing = <String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          if (failing.contains(call.method)) {
            throw PlatformException(code: 'error', message: 'boom');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('raster', () {
    test('reports a failed rasterPdf call on the stream', () async {
      failing.add('rasterPdf');
      final pending = MethodChannelPrinting.pendingJobs;
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        await expectLater(
          impl.raster(Uint8List.fromList(<int>[1, 2, 3]), null, 72),
          emitsInOrder(<dynamic>[
            emitsError(isA<PlatformException>()),
            emitsDone,
          ]),
        );
      }, (Object e, StackTrace s) => zoneErrors.add(e));

      expect(zoneErrors, isEmpty, reason: 'the error must not escape the zone');
      expect(MethodChannelPrinting.pendingJobs, pending);
    });

    test('keeps the stream open when the platform accepts the call', () async {
      final pending = MethodChannelPrinting.pendingJobs;
      final pages = <PdfRaster>[];
      var done = false;
      final sub = impl
          .raster(Uint8List.fromList(<int>[1, 2, 3]), null, 72)
          .listen(pages.add, onDone: () => done = true);
      await pumpEventQueue();

      final job = jobOf('rasterPdf');
      expect(done, isFalse, reason: 'a successful call must not close it');

      await sendPage(job);
      await sendPage(job);
      expect(pages, hasLength(2));
      expect(done, isFalse);

      await endRaster(job);
      await pumpEventQueue();
      expect(done, isTrue);
      expect(MethodChannelPrinting.pendingJobs, pending);
      await sub.cancel();
    });

    test('forwards an onPageRasterEnd error', () async {
      final pending = MethodChannelPrinting.pendingJobs;
      Object? error;
      var done = false;
      final sub = impl
          .raster(Uint8List.fromList(<int>[1, 2, 3]), null, 72)
          .listen(
            (_) {},
            onError: (Object e) => error = e,
            onDone: () => done = true,
          );
      await pumpEventQueue();

      await endRaster(jobOf('rasterPdf'), error: 'boom');
      await pumpEventQueue();

      expect(error, 'boom');
      expect(done, isTrue);
      expect(MethodChannelPrinting.pendingJobs, pending);
      await sub.cancel();
    });

    test('a late onPageRasterized after a failure is a no-op', () async {
      failing.add('rasterPdf');
      final zoneErrors = <Object>[];
      late int job;

      await runZonedGuarded(() async {
        final stream = impl.raster(
          Uint8List.fromList(<int>[1, 2, 3]),
          null,
          72,
        );
        await expectLater(
          stream,
          emitsInOrder(<dynamic>[
            emitsError(isA<PlatformException>()),
            emitsDone,
          ]),
        );
        job = jobOf('rasterPdf');
      }, (Object e, StackTrace s) => zoneErrors.add(e));

      final reply = await sendPage(job);
      expect(reply, isNotNull);
      expect(() => _codec.decodeEnvelope(reply!), returnsNormally);
      expect(await endRaster(job), isNotNull);
      expect(zoneErrors, isEmpty);
    });

    test('cancelling early unregisters the job', () async {
      final pending = MethodChannelPrinting.pendingJobs;
      final sub = impl
          .raster(Uint8List.fromList(<int>[1, 2, 3]), null, 72)
          .listen((_) {});
      await pumpEventQueue();
      expect(MethodChannelPrinting.pendingJobs, pending + 1);

      await sub.cancel();
      expect(MethodChannelPrinting.pendingJobs, pending);
    });
  });

  group('layoutPdf', () {
    Future<bool> layout(LayoutCallback onLayout) => impl.layoutPdf(
      null,
      onLayout,
      'document',
      PdfPageFormat.a4,
      true,
      false,
      OutputType.generic,
      false,
      false,
    );

    test('unregisters the job when printPdf fails', () async {
      failing.add('printPdf');
      final pending = MethodChannelPrinting.pendingJobs;
      var layoutCalls = 0;

      await expectLater(
        layout((PdfPageFormat format) async {
          layoutCalls++;
          return Uint8List(0);
        }),
        throwsA(isA<PlatformException>()),
      );

      expect(MethodChannelPrinting.pendingJobs, pending);

      // The platform may still call back; it must not reach the caller.
      await fromPlatform('onLayout', <String, dynamic>{
        'job': jobOf('printPdf'),
        'width': 595.0,
        'height': 842.0,
        'marginLeft': 0.0,
        'marginTop': 0.0,
        'marginRight': 0.0,
        'marginBottom': 0.0,
      });
      expect(layoutCalls, 0);
    });

    test(
      'unregisters the job when the platform reports it completed',
      () async {
        final pending = MethodChannelPrinting.pendingJobs;
        final result = layout((PdfPageFormat format) async => Uint8List(0));
        await pumpEventQueue();

        final job = jobOf('printPdf');
        await fromPlatform('onCompleted', <String, dynamic>{
          'job': job,
          'completed': true,
        });

        expect(await result, isTrue);
        expect(MethodChannelPrinting.pendingJobs, pending);

        // A second callback for the same job is a no-op, not a 'Bad state'.
        final reply = await fromPlatform('onCompleted', <String, dynamic>{
          'job': job,
          'completed': true,
        });
        expect(() => _codec.decodeEnvelope(reply!), returnsNormally);
      },
    );
  });

  group('convertHtml', () {
    test('unregisters the job when the platform reports onHtmlError', () async {
      final pending = MethodChannelPrinting.pendingJobs;
      final result = impl.convertHtml('<p>x</p>', null, PdfPageFormat.a4);
      final expectation = expectLater(result, throwsA('nope'));
      await pumpEventQueue();

      final job = jobOf('convertHtml');
      await fromPlatform('onHtmlError', <String, dynamic>{
        'job': job,
        'error': 'nope',
      });
      await expectation;

      expect(MethodChannelPrinting.pendingJobs, pending);

      // Android can report an error and then a success for the same job; the
      // second call must be ignored instead of completing the future twice.
      final reply = await fromPlatform('onHtmlError', <String, dynamic>{
        'job': job,
        'error': 'again',
      });
      expect(() => _codec.decodeEnvelope(reply!), returnsNormally);
    });

    test('unregisters the job when invokeMethod throws', () async {
      failing.add('convertHtml');
      final pending = MethodChannelPrinting.pendingJobs;
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        await expectLater(
          impl.convertHtml('<p>x</p>', null, PdfPageFormat.a4),
          throwsA(isA<PlatformException>()),
        );
        final reply = await fromPlatform('onHtmlError', <String, dynamic>{
          'job': jobOf('convertHtml'),
          'error': 'late',
        });
        expect(() => _codec.decodeEnvelope(reply!), returnsNormally);
      }, (Object e, StackTrace s) => zoneErrors.add(e));

      expect(MethodChannelPrinting.pendingJobs, pending);
      expect(zoneErrors, isEmpty);
    });

    test('unregisters the job on success', () async {
      final pending = MethodChannelPrinting.pendingJobs;
      final result = impl.convertHtml('<p>x</p>', null, PdfPageFormat.a4);
      await pumpEventQueue();

      final job = jobOf('convertHtml');
      await fromPlatform('onHtmlRendered', <String, dynamic>{
        'job': job,
        'doc': Uint8List.fromList(<int>[1, 2]),
      });

      expect(await result, <int>[1, 2]);
      expect(MethodChannelPrinting.pendingJobs, pending);
    });
  });
}
