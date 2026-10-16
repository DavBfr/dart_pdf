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

import 'package:flutter/foundation.dart';
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
  late Map<String, Object?> replies;

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
    replies = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          if (failing.contains(call.method)) {
            throw PlatformException(code: 'error', message: 'boom');
          }
          return replies[call.method];
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

    // These two pin the contract the native backends have to honour: a job
    // that ends for any reason sends exactly one onCompleted. They pass
    // against the Dart code at HEAD; the Linux plugin is what did not send it.
    test('a cancellation reports false rather than an error', () async {
      final result = layout((PdfPageFormat format) async => Uint8List(0));
      await pumpEventQueue();

      // What cancel_job(nullptr) puts on the channel.
      await fromPlatform('onCompleted', <String, dynamic>{
        'job': jobOf('printPdf'),
        'completed': false,
        'error': null,
      });

      expect(await result, isFalse);
    });

    test(
      'a failing onLayout completes with the error the platform sends',
      () async {
        final reported = <Object>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) =>
            reported.add(details.exception);
        addTearDown(() => FlutterError.onError = previousOnError);

        final result = layout(
          (PdfPageFormat format) async => throw Exception('no document'),
        );
        final expectation = expectLater(result, throwsA('no document'));
        await pumpEventQueue();

        final job = jobOf('printPdf');
        // The onLayout reply is an error, so nothing is written and the native
        // side has to end the job itself. Without that onCompleted the future
        // never settles - which is what the empty Linux cancel_job caused.
        final reply = await fromPlatform('onLayout', <String, dynamic>{
          'job': job,
          'width': 595.0,
          'height': 842.0,
          'marginLeft': 0.0,
          'marginTop': 0.0,
          'marginRight': 0.0,
          'marginBottom': 0.0,
        });
        expect(
          () => _codec.decodeEnvelope(reply!),
          throwsA(
            isA<PlatformException>().having(
              (PlatformException e) => e.message,
              'message',
              isNotEmpty,
            ),
          ),
          // Android puts this text in the print dialog through
          // onLayoutFailed, so an empty message would leave the user with a
          // blank error.
          reason: 'the platform sees a failed onLayout, with a message',
        );
        expect(reported, hasLength(1), reason: 'the build failure is reported');

        await fromPlatform('onCompleted', <String, dynamic>{
          'job': job,
          'completed': false,
          'error': 'no document',
        });
        await expectation;
      },
    );

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

  group('page format', () {
    test('an unspecified axis crosses the channel as zero', () async {
      unawaited(
        impl
            .layoutPdf(
              null,
              (PdfPageFormat format) async => Uint8List(0),
              'document',
              PdfPageFormat.roll80,
              true,
              false,
              OutputType.generic,
              false,
              false,
            )
            .catchError((Object _) => false),
      );
      await pumpEventQueue();

      final call = calls.lastWhere((MethodCall c) => c.method == 'printPdf');
      expect(call.arguments['width'], closeTo(80 * PdfPageFormat.mm, 1e-6));
      expect(
        call.arguments['height'],
        0.0,
        reason: 'infinity cannot cross the channel',
      );
      for (final key in <String>[
        'marginLeft',
        'marginTop',
        'marginRight',
        'marginBottom',
      ]) {
        expect((call.arguments[key] as double).isFinite, isTrue);
      }

      await fromPlatform('onCompleted', <String, dynamic>{
        'job': jobOf('printPdf'),
        'completed': false,
      });
    });

    test('a non-finite size reported back is repaired', () async {
      PdfPageFormat? received;
      unawaited(
        impl
            .layoutPdf(
              null,
              (PdfPageFormat format) async {
                received = format;
                return Uint8List(0);
              },
              'document',
              PdfPageFormat.roll80,
              true,
              false,
              OutputType.generic,
              false,
              false,
            )
            .catchError((Object _) => false),
      );
      await pumpEventQueue();

      // What a backend that mishandled the unspecified axis sends: iOS used to
      // produce NaN margins this way, and the document got a NaN MediaBox.
      await fromPlatform('onLayout', <String, dynamic>{
        'job': jobOf('printPdf'),
        'width': 226.77,
        'height': double.infinity,
        'marginLeft': 14.17,
        'marginTop': 14.17,
        'marginRight': double.nan,
        'marginBottom': double.nan,
      });

      expect(received, isNotNull);
      expect(received!.width, closeTo(226.77, 1e-6));
      // An infinite height is meaningful for a roll - the page auto-sizes to
      // its content - but a NaN margin used to poison that computation and put
      // a NaN MediaBox in the document.
      expect(received!.height.isNaN, isFalse);
      expect(received!.marginRight, 0);
      expect(received!.marginBottom, 0);

      await fromPlatform('onCompleted', <String, dynamic>{
        'job': jobOf('printPdf'),
        'completed': false,
      });
    });

    test(
      'a bogus size reported back falls back to the requested one',
      () async {
        PdfPageFormat? received;
        unawaited(
          impl
              .layoutPdf(
                null,
                (PdfPageFormat format) async {
                  received = format;
                  return Uint8List(0);
                },
                'document',
                PdfPageFormat.a4,
                true,
                false,
                OutputType.generic,
                false,
                false,
              )
              .catchError((Object _) => false),
        );
        await pumpEventQueue();

        await fromPlatform('onLayout', <String, dynamic>{
          'job': jobOf('printPdf'),
          'width': double.nan,
          'height': double.nan,
          'marginLeft': 0.0,
          'marginTop': 0.0,
          'marginRight': 0.0,
          'marginBottom': 0.0,
        });

        expect(received, isNotNull);
        expect(received!.width, PdfPageFormat.a4.width);
        expect(received!.height, PdfPageFormat.a4.height);

        await fromPlatform('onCompleted', <String, dynamic>{
          'job': jobOf('printPdf'),
          'completed': false,
        });
      },
    );
  });

  group('convertHtml', () {
    test('the page format crosses the channel as size and margins', () async {
      // macOS builds its NSPrintInfo from these, so a missing margin is a
      // page that ignores the requested format.
      const format = PdfPageFormat(595, 842, marginAll: 20);
      final result = impl.convertHtml('<p>x</p>', null, format);
      final expectation = expectLater(result, throwsA('done'));
      await pumpEventQueue();

      final args = calls.last.arguments;
      expect(args['width'], 595.0);
      expect(args['height'], 842.0);
      expect(args['marginLeft'], 20.0);
      expect(args['marginTop'], 20.0);
      expect(args['marginRight'], 20.0);
      expect(args['marginBottom'], 20.0);
      expect(args['html'], '<p>x</p>');

      await fromPlatform('onHtmlError', <String, dynamic>{
        'job': jobOf('convertHtml'),
        'error': 'done',
      });
      await expectation;
    });

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

    test(
      'a second result arriving before the first is handled is ignored',
      () async {
        final pending = MethodChannelPrinting.pendingJobs;
        final result = impl.convertHtml('<p>x</p>', null, PdfPageFormat.a4);
        final expectation = expectLater(result, throwsA('first'));
        await pumpEventQueue();

        final job = jobOf('convertHtml');
        // Android's PdfConvert could report an error and then a success for one
        // job, both before the awaiting code resumed.
        await fromPlatform('onHtmlError', <String, dynamic>{
          'job': job,
          'error': 'first',
        });
        final reply = await fromPlatform('onHtmlRendered', <String, dynamic>{
          'job': job,
          'doc': Uint8List.fromList(<int>[9]),
        });
        expect(() => _codec.decodeEnvelope(reply!), returnsNormally);

        await expectation;
        expect(MethodChannelPrinting.pendingJobs, pending);
      },
    );

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

  group('sharePdf', () {
    const bounds = Rect.fromLTRB(0, 0, 1, 1);

    test('a missing reply is a failure, not a success', () async {
      // The platform answers nothing at all - an unimplemented backend, or one
      // that returned before deciding. That is not a share.
      expect(
        await impl.sharePdf(Uint8List(0), 'x.pdf', bounds, null, null, null),
        isFalse,
      );
    });

    test('a zero reply is a failure', () async {
      replies['sharePdf'] = 0;
      expect(
        await impl.sharePdf(Uint8List(0), 'x.pdf', bounds, null, null, null),
        isFalse,
      );
    });

    test('a non-zero reply is a success', () async {
      replies['sharePdf'] = 1;
      expect(
        await impl.sharePdf(Uint8List(0), 'x.pdf', bounds, null, null, null),
        isTrue,
      );
    });

    test('the name that crosses the channel carries no directory', () async {
      replies['sharePdf'] = 1;

      await Printing.sharePdf(
        bytes: Uint8List(0),
        filename: '../../../etc/passwd.pdf',
        bounds: Rect.fromLTRB(0, 0, 1, 1),
      );

      // Every backend joins this onto a temp directory, so a separator used to
      // point outside it.
      expect(calls.last.arguments['name'], 'passwd.pdf');
    });

    group('safeFilename', () {
      test('keeps an ordinary name', () {
        expect(Printing.safeFilename('report.pdf'), 'report.pdf');
      });

      test('drops a posix directory', () {
        expect(Printing.safeFilename('a/b/report.pdf'), 'report.pdf');
      });

      test('drops a windows directory', () {
        expect(Printing.safeFilename(r'a\b\report.pdf'), 'report.pdf');
      });

      test('refuses to escape the directory', () {
        expect(Printing.safeFilename('../../etc/passwd'), 'passwd');
        expect(Printing.safeFilename('..'), 'document.pdf');
        expect(Printing.safeFilename('../'), 'document.pdf');
      });

      test('falls back for a name that names no file', () {
        expect(Printing.safeFilename(''), 'document.pdf');
        expect(Printing.safeFilename('.'), 'document.pdf');
        expect(Printing.safeFilename('   '), 'document.pdf');
        expect(Printing.safeFilename('a/'), 'document.pdf');
      });

      test('honours the caller fallback', () {
        expect(Printing.safeFilename('', fallback: 'other.pdf'), 'other.pdf');
      });
    });
  });

  group('listPrinters', () {
    test('a platform failure reaches the caller', () async {
      // Windows answered an empty list when the spooler was stopped, so an app
      // could not tell 'no printers' from 'the print system is down'.
      failing.add('listPrinters');

      await expectLater(impl.listPrinters(), throwsA(isA<PlatformException>()));
    });

    test('a null reply is an empty list, not a null-check error', () async {
      expect(await impl.listPrinters(), isEmpty);
    });

    test('a printer without a location or a comment is accepted', () async {
      replies['listPrinters'] = <Object?>[
        <String, Object?>{
          'url': 'ipp://p',
          'name': 'p',
          'model': null,
          'default': false,
          'available': true,
        },
      ];

      final printers = await impl.listPrinters();

      expect(printers, hasLength(1));
      expect(printers.first.name, 'p');
      expect(printers.first.location, isNull);
      expect(printers.first.comment, isNull);
    });
  });

  group('printPdf arguments', () {
    // What reaches the native side decides what the print sheet does: iOS
    // builds its UIPrintInfo from the output type and the page size, and only
    // asks Dart for a document up front when 'dynamic' is false.
    Future<void> layout({
      Printer? printer,
      PdfPageFormat format = PdfPageFormat.a4,
      bool dynamicLayout = true,
      OutputType outputType = OutputType.generic,
    }) async {
      final result = impl.layoutPdf(
        printer,
        (PdfPageFormat format) async => Uint8List(0),
        'document.pdf',
        format,
        dynamicLayout,
        false,
        outputType,
        false,
        false,
      );
      await pumpEventQueue();
      await fromPlatform('onCompleted', <String, dynamic>{
        'job': jobOf('printPdf'),
        'completed': true,
      });
      await result;
    }

    test('the output type crosses the channel as its index', () async {
      await layout(outputType: OutputType.grayscale);

      expect(calls.last.arguments['outputType'], OutputType.grayscale.index);
      expect(
        OutputType.grayscale.index,
        2,
        reason: 'the native side reads an index',
      );
    });

    test('a static layout is requested as dynamic: false', () async {
      await layout(dynamicLayout: false);

      expect(calls.last.arguments['dynamic'], isFalse);
    });

    test('a landscape format keeps its own axes', () async {
      await layout(format: PdfPageFormat.a4.landscape);

      expect(
        calls.last.arguments['width'],
        greaterThan(calls.last.arguments['height']),
      );
    });

    test('directPrintPdf names its printer', () async {
      const printer = Printer(url: 'ipp://printer', name: 'printer');
      await layout(printer: printer, dynamicLayout: false);

      final args = calls.last.arguments;
      expect(args['printer'], 'ipp://printer');
      expect(args['name'], 'document.pdf');
      expect(args['dynamic'], isFalse);
      expect(args['width'], PdfPageFormat.a4.width);
      expect(args['marginLeft'], PdfPageFormat.a4.marginLeft);
    });

    test('a failed job start makes the future throw', () async {
      // What the iOS side now reports when print(to:) or present() refuses.
      final result = impl.layoutPdf(
        const Printer(url: 'ipp://printer', name: 'printer'),
        (PdfPageFormat format) async => Uint8List(0),
        'document',
        PdfPageFormat.a4,
        false,
        false,
        OutputType.generic,
        false,
        false,
      );
      final expectation = expectLater(
        result,
        throwsA('Unable to start the print job'),
      );
      await pumpEventQueue();

      await fromPlatform('onCompleted', <String, dynamic>{
        'job': jobOf('printPdf'),
        'completed': false,
        'error': 'Unable to start the print job',
      });

      await expectation;
    });
  });
}
