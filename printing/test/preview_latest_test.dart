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
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/src/interface.dart';
import 'package:printing/src/preview/custom.dart';
import 'package:printing/src/printing_info.dart';
import 'package:printing/src/raster.dart';

class _PreviewPrinting extends PrintingPlatform {
  /// First byte of every document handed to [raster].
  final rasterized = <int>[];

  /// Overrides the empty raster stream when set.
  Stream<PdfRaster> Function()? onRaster;

  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);

  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) {
    rasterized.add(document.first);
    return onRaster?.call() ?? const Stream<PdfRaster>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _PreviewPrinting platform;

  setUp(() {
    final original = PrintingPlatform.instance;
    platform = _PreviewPrinting();
    PrintingPlatform.instance = platform;
    addTearDown(() => PrintingPlatform.instance = original);
  });

  // Lets the 300ms preview debounce elapse.
  Future<void> debounce(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 350));

  testWidgets('new page format is rendered after an earlier build completes', (
    tester,
  ) async {
    final firstBuild = Completer<Uint8List>();
    final formats = <PdfPageFormat>[];
    Future<Uint8List> build(PdfPageFormat format) {
      formats.add(format);
      if (formats.length == 1) {
        return firstBuild.future;
      }
      return Future.value(Uint8List.fromList([formats.length]));
    }

    Widget preview(PdfPageFormat format) => MaterialApp(
      home: PdfPreviewCustom(pageFormat: format, build: build, dpi: 72),
    );

    await tester.pumpWidget(preview(PdfPageFormat.a4));
    await debounce(tester);
    expect(formats, [PdfPageFormat.a4]);

    await tester.pumpWidget(preview(PdfPageFormat.letter));
    await debounce(tester);
    expect(formats, hasLength(1));

    // Replacing a pending request must retain only the latest selection.
    await tester.pumpWidget(preview(PdfPageFormat.a5));
    await debounce(tester);
    expect(formats, hasLength(1));

    firstBuild.complete(Uint8List.fromList([1]));
    await tester.pump();
    await tester.pump();

    expect(formats, [PdfPageFormat.a4, PdfPageFormat.a5]);
    // The superseded document is never rasterized.
    expect(platform.rasterized, [2]);
  });

  testWidgets('disposing during a slow build stops further renders', (
    tester,
  ) async {
    final firstBuild = Completer<Uint8List>();
    var builds = 0;
    Future<Uint8List> build(PdfPageFormat format) {
      builds++;
      return builds == 1 ? firstBuild.future : Future.value(Uint8List(1));
    }

    Widget preview(PdfPageFormat format) => MaterialApp(
      home: PdfPreviewCustom(pageFormat: format, build: build, dpi: 72),
    );

    await tester.pumpWidget(preview(PdfPageFormat.a4));
    await debounce(tester);
    await tester.pumpWidget(preview(PdfPageFormat.a5));
    await debounce(tester);
    expect(builds, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    firstBuild.complete(Uint8List(1));
    await tester.pump();
    await tester.pump();

    expect(builds, 1);
    expect(platform.rasterized, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer request cancels the stale raster stream', (
    tester,
  ) async {
    final controller = StreamController<PdfRaster>();
    var cancelled = false;
    // An async callback keeps the cancel future inside the fake-async zone.
    controller.onCancel = () async => cancelled = true;
    platform.onRaster = () {
      platform.onRaster = null;
      return controller.stream;
    };

    final formats = <PdfPageFormat>[];
    Future<Uint8List> build(PdfPageFormat format) async {
      formats.add(format);
      return Uint8List.fromList([formats.length]);
    }

    Widget preview(PdfPageFormat format) => MaterialApp(
      home: PdfPreviewCustom(pageFormat: format, build: build, dpi: 72),
    );

    await tester.pumpWidget(preview(PdfPageFormat.a4));
    await debounce(tester);
    expect(platform.rasterized, [1]);

    await tester.pumpWidget(preview(PdfPageFormat.a5));
    await debounce(tester);
    expect(formats, [PdfPageFormat.a4]);

    // The stale page is dropped before PNG encoding, which ends the old stream.
    controller.add(PdfRaster(1, 1, Uint8List(4)));
    await tester.pump();
    await tester.pump();

    expect(cancelled, isTrue);
    expect(formats, [PdfPageFormat.a4, PdfPageFormat.a5]);
    expect(platform.rasterized, [1, 2]);
    expect(find.byType(Image), findsNothing);
  });
}
