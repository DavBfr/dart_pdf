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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Counts what Flutter creates and disposes while a body runs.
class _Allocations {
  final created = <String, int>{};
  final disposed = <String, int>{};

  void _record(ObjectEvent event) {
    final name = event.object.runtimeType.toString();
    if (event is ObjectCreated) {
      created[name] = (created[name] ?? 0) + 1;
    } else if (event is ObjectDisposed) {
      disposed[name] = (disposed[name] ?? 0) + 1;
    }
  }

  /// Classes created more often than they were disposed.
  Map<String, int> get leaked {
    final result = <String, int>{};
    created.forEach((String name, int count) {
      final free = disposed[name] ?? 0;
      if (count > free) {
        result[name] = count - free;
      }
    });
    return result;
  }

  Future<T> watch<T>(Future<T> Function() body) async {
    FlutterMemoryAllocations.instance.addListener(_record);
    try {
      return await body();
    } finally {
      FlutterMemoryAllocations.instance.removeListener(_record);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fromWidget', () {
    testWidgets('rejects an unbounded width', (tester) async {
      // Only the height used to be tested, twice, so this fell through to a
      // block that reported something else entirely.
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            expect(
              () => WidgetWrapper.fromWidget(
                context: context,
                widget: const SizedBox(),
                constraints: const BoxConstraints(maxHeight: 20),
              ),
              throwsA(
                isA<Exception>().having(
                  (Exception e) => e.toString(),
                  'message',
                  contains('Add maxWidth and maxHeight'),
                ),
              ),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('rejects an unbounded height', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            expect(
              () => WidgetWrapper.fromWidget(
                context: context,
                widget: const SizedBox(),
                constraints: const BoxConstraints(maxWidth: 30),
              ),
              throwsA(
                isA<Exception>().having(
                  (Exception e) => e.toString(),
                  'message',
                  contains('Add maxWidth and maxHeight'),
                ),
              ),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('captures a bounded widget without reading diagnostics', (
      tester,
    ) async {
      // The path this takes used to depend on asserts being enabled: it read
      // the constraints back out of debug diagnostics, which are empty in a
      // release or profile build, and threw before rendering anything.
      WidgetWrapper? wrapped;

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            wrapped = null;
            unawaited(
              WidgetWrapper.fromWidget(
                context: context,
                widget: const SizedBox(
                  width: 20,
                  height: 10,
                  child: ColoredBox(color: Colors.amber),
                ),
                constraints: const BoxConstraints(maxWidth: 20, maxHeight: 10),
                pixelRatio: 2,
              ).then((WidgetWrapper value) => wrapped = value),
            );
            return const SizedBox();
          },
        ),
      );

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(wrapped, isNotNull);
      expect(wrapped!.width, 40);
      expect(wrapped!.height, 20);
      expect(wrapped!.bytes, hasLength(40 * 20 * 4));
    });

    testWidgets('tears down everything it creates', (tester) async {
      final allocations = _Allocations();
      WidgetWrapper? wrapped;

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            unawaited(
              allocations
                  .watch(
                    () => WidgetWrapper.fromWidget(
                      context: context,
                      widget: const SizedBox(
                        width: 20,
                        height: 10,
                        child: ColoredBox(color: Colors.amber),
                      ),
                      constraints: const BoxConstraints(
                        maxWidth: 20,
                        maxHeight: 10,
                      ),
                    ),
                  )
                  .then((WidgetWrapper value) => wrapped = value),
            );
            return const SizedBox();
          },
        ),
      );

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(wrapped, isNotNull);
      // FocusManager registers a WidgetsBinding observer that only its
      // dispose() removes, so one used to be added permanently per call.
      for (final name in <String>[
        'FocusManager',
        'PipelineOwner',
        'RenderView',
        'RenderPositionedBox',
        'RenderRepaintBoundary',
      ]) {
        expect(
          allocations.leaked,
          isNot(contains(name)),
          reason: '$name leaked: ${allocations.leaked}',
        );
      }
    });

    testWidgets('tears down everything even when the capture throws', (
      tester,
    ) async {
      final allocations = _Allocations();
      Object? error;

      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            unawaited(
              allocations
                  .watch(
                    () => WidgetWrapper.fromWidget(
                      context: context,
                      // Lays out to nothing, so toImage throws 'Invalid image
                      // dimensions.'
                      widget: const SizedBox.shrink(),
                      constraints: const BoxConstraints(
                        maxWidth: 0,
                        maxHeight: 0,
                      ),
                    ),
                  )
                  .then<void>(
                    (WidgetWrapper _) {},
                    onError: (Object e) => error = e,
                  ),
            );
            return const SizedBox();
          },
        ),
      );

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(error, isNotNull);
      for (final name in <String>[
        'FocusManager',
        'PipelineOwner',
        'RenderView',
      ]) {
        expect(
          allocations.leaked,
          isNot(contains(name)),
          reason: '$name leaked on the throw path: ${allocations.leaked}',
        );
      }
    });
  });

  group('the captured buffer', () {
    /// Capture [widget] at [size] logical pixels.
    Future<WidgetWrapper> capture(
      WidgetTester tester,
      Widget widget, {
      double width = 40,
      double height = 20,
      PdfImageOrientation? orientation,
      double? dpi,
    }) async {
      WidgetWrapper? wrapped;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            wrapped = null;
            unawaited(
              WidgetWrapper.fromWidget(
                context: context,
                // An explicit size: IntrinsicWidth/IntrinsicHeight wrap the
                // widget, and a box with no intrinsic size of its own lays out
                // to nothing, which makes toImage throw.
                widget: SizedBox(width: width, height: height, child: widget),
                constraints: BoxConstraints(maxWidth: width, maxHeight: height),
                orientation: orientation,
                dpi: dpi,
              ).then((WidgetWrapper value) => wrapped = value),
            );
            return const SizedBox();
          },
        ),
      );

      // The capture goes through the engine, so it needs real time to finish.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(wrapped, isNotNull, reason: 'the capture completed');
      return wrapped!;
    }

    /// Resolve [provider] at [size] and hand back the PdfImage it built.
    Future<PdfImage> resolve(
      pw.ImageProvider provider,
      PdfPoint size, {
      double? dpi,
    }) async {
      late PdfImage image;
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(600, 600, marginAll: 0),
          build: (pw.Context context) {
            image = provider.resolve(context, size, dpi: dpi);
            return pw.SizedBox();
          },
        ),
      );
      await document.save();
      return image;
    }

    testWidgets('carries straight alpha, not premultiplied', (tester) async {
      // dart:ui returns premultiplied RGBA by default and the PDF layer stores
      // it as /DeviceRGB plus a /DeviceGray /SMask, which the spec defines as
      // straight alpha - so a viewer composited Cs*a^2 + Cb*(1-a). 50% red came
      // out (191,127,127) over white instead of (255,127,127), and every
      // anti-aliased edge had a dark fringe.
      final wrapped = await capture(
        tester,
        Container(color: const Color(0x80ff0000)),
      );

      expect(wrapped.bytes, isNotEmpty);
      expect(wrapped.bytes[0], closeTo(255, 1), reason: 'red');
      expect(wrapped.bytes[1], closeTo(0, 1), reason: 'green');
      expect(wrapped.bytes[2], closeTo(0, 1), reason: 'blue');
      expect(wrapped.bytes[3], closeTo(128, 1), reason: 'alpha');
    });

    testWidgets('is described by the dimensions it is handed over with', (
      tester,
    ) async {
      // buildImage passed ImageProvider's display getters, which swap the two
      // axes for a rotated orientation, as PdfImage's raw stream dimensions -
      // and PdfImage writes them straight into /Width and /Height and drives its
      // pixel loops with them. A rotated capture decoded at the wrong row
      // stride.
      for (final orientation in PdfImageOrientation.values) {
        final wrapped = await capture(
          tester,
          Container(color: const Color(0xff00ff00)),
          orientation: orientation,
        );
        final image = await resolve(wrapped, const PdfPoint(600, 600));
        final what = '$orientation';

        expect(image.params['/Width'].toString(), '40', reason: what);
        expect(image.params['/Height'].toString(), '20', reason: what);
        expect(image.orientation, orientation, reason: what);

        // And the display values still come from the provider.
        expect(image.width, wrapped.width, reason: what);
        expect(image.height, wrapped.height, reason: what);
      }
    });

    testWidgets('is resampled when a resample is asked for', (tester) async {
      // The full-resolution capture used to be handed over labelled with the
      // requested size, so the RGB and SMask loops read at the wrong stride -
      // a diagonally sheared sliver of the top of the widget. The labels alone
      // looked right, so this reads the stream behind them: red over blue, and
      // the bottom half of the resampled picture still has to be blue.
      final wrapped = await capture(
        tester,
        Column(
          children: <Widget>[
            SizedBox(
              width: 400,
              height: 100,
              child: ColoredBox(color: const Color(0xffff0000)),
            ),
            SizedBox(
              width: 400,
              height: 100,
              child: ColoredBox(color: const Color(0xff0000ff)),
            ),
          ],
        ),
        width: 400,
        height: 200,
      );
      expect(wrapped.width, 400);
      expect(wrapped.bytes, hasLength(400 * 200 * 4));
      // ignore: avoid_print
      print(
        'capture top ${wrapped.bytes.sublist(200 * 4, 200 * 4 + 4)} '
        'mid ${wrapped.bytes.sublist((150 * 400 + 200) * 4, (150 * 400 + 200) * 4 + 4)}',
      );

      final image = await resolve(
        wrapped,
        const PdfPoint(100, 50),
        dpi: PdfPageFormat.inch,
      );

      expect(image.params['/Width'].toString(), '100');
      expect(image.params['/Height'].toString(), '50');

      // Three bytes a pixel, and no more than the picture it describes.
      final rgb = image.buf.output();
      expect(rgb, hasLength(100 * 50 * 3));

      // Row 40 of 50 is in the bottom half, so it is blue.
      // ignore: avoid_print
      print(
        <String>[
          for (final row in <int>[5, 20, 30, 45])
            'row $row: ${rgb.sublist((row * 100 + 50) * 3, (row * 100 + 50) * 3 + 3)}',
        ].toString(),
      );
      final pixel = (40 * 100 + 50) * 3;
      expect(rgb[pixel], lessThan(40), reason: 'red');
      expect(rgb[pixel + 2], greaterThan(200), reason: 'blue');
    });

    testWidgets('does not read past its own end for a stretched box', (
      tester,
    ) async {
      // BoxFit.fill asks for a target whose pixel count exceeds the capture's:
      // the SMask loop walked off the end and Document.save() threw a RangeError.
      final wrapped = await capture(
        tester,
        Container(color: const Color(0xff0000ff)),
        width: 400,
        height: 200,
      );

      final image = await resolve(
        wrapped,
        const PdfPoint(100, 900),
        dpi: PdfPageFormat.inch,
      );

      expect(image.params['/Width'].toString(), '100');
      expect(image.params['/Height'].toString(), '50');
      expect(image.buf.output(), hasLength(100 * 50 * 3));
    });

    testWidgets('keeps its own pixels when the target is larger', (
      tester,
    ) async {
      final wrapped = await capture(
        tester,
        Container(color: const Color(0xff0000ff)),
        width: 400,
        height: 200,
      );

      final image = await resolve(
        wrapped,
        const PdfPoint(800, 400),
        dpi: PdfPageFormat.inch,
      );

      expect(image.params['/Width'].toString(), '400');
      expect(image.params['/Height'].toString(), '200');
      expect(image.buf.output(), hasLength(400 * 200 * 3));
    });
  });

  group('fromKey', () {
    testWidgets('disposes the image it captured', (tester) async {
      const key = GlobalObjectKey(#wrapperTest);
      final allocations = _Allocations();

      // Centred, so the boundary takes the box's size rather than the whole
      // test surface.
      await tester.pumpWidget(
        const Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 10,
              height: 10,
              child: ColoredBox(color: Colors.amber),
            ),
          ),
        ),
      );

      late WidgetWrapper wrapped;
      await tester.runAsync(
        () => allocations
            .watch(() => WidgetWrapper.fromKey(key: key))
            .then((WidgetWrapper value) => wrapped = value),
      );

      expect(wrapped.bytes, hasLength(10 * 10 * 4));
      expect(
        allocations.leaked,
        isNot(contains('Image')),
        reason: 'the full-resolution image was never released',
      );
    });
  });
}
