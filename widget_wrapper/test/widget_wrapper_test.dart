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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_widget_wrapper/pdf_widget_wrapper.dart';

/// Runs [body] and records the [ui.Image]s it created but did not dispose.
Future<T?> _trackImages<T>(
  Set<ui.Image> open,
  Future<T?> Function() body,
) async {
  final previousOnCreate = ui.Image.onCreate;
  final previousOnDispose = ui.Image.onDispose;
  ui.Image.onCreate = (image) {
    open.add(image);
    previousOnCreate?.call(image);
  };
  ui.Image.onDispose = (image) {
    open.remove(image);
    previousOnDispose?.call(image);
  };
  try {
    return await body();
  } finally {
    ui.Image.onCreate = previousOnCreate;
    ui.Image.onDispose = previousOnDispose;
  }
}

void main() {
  testWidgets('fromKey copies the pixels and releases the captured image', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: const SizedBox(
            width: 20,
            height: 12,
            child: ColoredBox(color: Color(0xffff0000)),
          ),
        ),
      ),
    );

    final undisposed = <ui.Image>{};
    final result = await _trackImages(
      undisposed,
      () => tester.runAsync(() => WidgetWrapper.fromKey(key: key)),
    );

    expect(undisposed, isEmpty);
    expect(result!.width, 20);
    expect(result.height, 12);
    expect(result.bytes.length, 20 * 12 * 4);
    expect(result.bytes.sublist(0, 4), [0xff, 0x00, 0x00, 0xff]);
  });

  testWidgets('fromWidget copies the pixels and releases the captured image', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    final undisposed = <ui.Image>{};
    final result = await _trackImages(
      undisposed,
      () => tester.runAsync(
        () => WidgetWrapper.fromWidget(
          context: context,
          widget: const SizedBox(
            width: 20,
            height: 12,
            child: ColoredBox(color: Color(0xff0000ff)),
          ),
          constraints: const BoxConstraints(maxWidth: 100, maxHeight: 100),
        ),
      ),
    );

    expect(undisposed, isEmpty);
    expect(result!.width, 20);
    expect(result.height, 12);
    expect(result.bytes.sublist(0, 4), [0x00, 0x00, 0xff, 0xff]);
  });
}
