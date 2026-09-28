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
