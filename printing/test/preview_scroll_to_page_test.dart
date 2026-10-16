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

  final key = GlobalKey<PdfPreviewCustomState>();

  Widget host({bool enableScrollToPage = true, Key? buildKey}) => MaterialApp(
    home: SizedBox(
      height: 600,
      child: PdfPreviewCustom(
        key: key,
        dpi: 72,
        enableScrollToPage: enableScrollToPage,
        // A new closure re-rasters, which is how a test asks for another pass.
        build: buildKey == null ? _build : (_) async => Uint8List(0),
      ),
    ),
  );

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

  /// Scroll to [index] and let the animation finish.
  ///
  /// The returned future completes with the scroll, so a call that never
  /// finishes fails the test by timing out.
  Future<void> scroll(
    WidgetTester tester,
    PdfPreviewCustomState state,
    int index,
  ) async {
    final scrolled = state.scrollToPage(index, duration: Duration.zero);
    await tester.pump();
    await scrolled;
  }

  /// Rasterize [count] pages and finish the job.
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

  group('page keys', () {
    testWidgets('are the same object across an unrelated rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await deliver(tester, 2);

      final state = key.currentState!;
      expect(state.pageCount, 2);

      final first = state.getPageKey(0);
      final context = (first as GlobalKey).currentContext;
      expect(context, isNotNull, reason: 'the key must be attached');

      // Any rebuild of the preview. The keys used to be reallocated inside
      // build, so this deactivated and re-inflated every page.
      await tester.pumpWidget(host());
      await tester.pump();

      expect(identical(state.getPageKey(0), first), isTrue);
      expect((state.getPageKey(0) as GlobalKey).currentContext, isNotNull);
      expect(context!.mounted, isTrue);
    });

    testWidgets('inflate each page element exactly once', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);

      final seen = <Element>{};
      for (var i = 0; i < 4; i++) {
        await sendPage();
        await settle(tester);
        seen.addAll(find.byType(PdfPreviewPage).evaluate());
      }
      final ended = endRaster();
      await settle(tester);
      await ended;
      await settle(tester);
      seen.addAll(find.byType(PdfPreviewPage).evaluate());

      expect(
        seen,
        hasLength(4),
        reason: 'a page that did not change must keep its element',
      );
    });

    testWidgets('survive a shrinking re-raster', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await deliver(tester, 3);

      final state = key.currentState!;
      expect(state.pageCount, 3);
      final first = state.getPageKey(0);

      // A new build closure re-rasters, and this pass yields one page.
      await tester.pumpWidget(host(buildKey: const ValueKey<int>(1)));
      await startRaster(tester);
      await deliver(tester, 1);

      expect(state.pageCount, 1);
      expect(identical(state.getPageKey(0), first), isTrue);
      await scroll(tester, state, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('are not allocated without enableScrollToPage', (tester) async {
      await tester.pumpWidget(host(enableScrollToPage: false));
      await startRaster(tester);
      await deliver(tester, 2);

      final state = key.currentState!;
      expect(state.pageCount, 2);
      expect(() => state.getPageKey(0), throwsAssertionError);
    });
  });

  group('scrollToPage', () {
    testWidgets('before the first raster is a no-op', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);

      // No page delivered: the key list is empty, which used to be a
      // 'RangeError (length): Valid value range is empty: 0'.
      final state = key.currentState!;
      expect(state.pageCount, 0);
      expect(() => state.scrollToPage(0), throwsAssertionError);
    });

    testWidgets('past the end after the document shrinks completes', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await deliver(tester, 2);
      await scroll(tester, key.currentState!, 1);

      await tester.pumpWidget(host(buildKey: const ValueKey<int>(1)));
      await startRaster(tester);
      await deliver(tester, 1);

      final state = key.currentState!;
      expect(state.pageCount, 1);
      expect(() => state.scrollToPage(1), throwsAssertionError);
    });

    testWidgets('a negative index still trips its own assert', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await deliver(tester, 1);

      expect(
        () => key.currentState!.scrollToPage(-1),
        throwsA(
          isA<AssertionError>().having(
            (AssertionError e) => e.message,
            'message',
            contains('cannot be negative'),
          ),
        ),
      );
    });

    testWidgets('scrolls a laid-out page into view', (tester) async {
      await tester.pumpWidget(host());
      await startRaster(tester);
      await deliver(tester, 3);

      await scroll(tester, key.currentState!, 2);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<Uint8List> _build(_) async => Uint8List(0);
