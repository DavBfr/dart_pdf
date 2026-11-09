import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/src/interface.dart';
import 'package:printing/src/printing_info.dart';
import 'package:printing/src/preview/custom.dart';
import 'package:printing/src/raster.dart';

class _PreviewPrinting extends PrintingPlatform {
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) => const Stream<PdfRaster>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('new page format is rendered after an earlier build completes', (
    tester,
  ) async {
    final original = PrintingPlatform.instance;
    PrintingPlatform.instance = _PreviewPrinting();
    addTearDown(() => PrintingPlatform.instance = original);

    final firstBuild = Completer<Uint8List>();
    final formats = <PdfPageFormat>[];
    Future<Uint8List> build(PdfPageFormat format) {
      formats.add(format);
      if (formats.length == 1) {
        return firstBuild.future;
      }
      return Future.value(Uint8List(0));
    }

    final key = GlobalKey<PdfPreviewCustomState>();
    Widget preview(PdfPageFormat format) => MaterialApp(
      home: PdfPreviewCustom(
        key: key,
        pageFormat: format,
        build: build,
        dpi: 72,
        loadingWidget: const Text('Generating'),
      ),
    );

    await tester.pumpWidget(preview(PdfPageFormat.a4));
    await tester.pump(const Duration(milliseconds: 350));
    expect(formats, [PdfPageFormat.a4]);

    await tester.pumpWidget(preview(PdfPageFormat.letter));
    await tester.pump(const Duration(milliseconds: 350));
    expect(formats, hasLength(1));

    // Replacing a pending request must retain only the latest selection.
    await tester.pumpWidget(preview(PdfPageFormat.a5));
    await tester.pump(const Duration(milliseconds: 350));
    expect(formats, hasLength(1));

    firstBuild.complete(Uint8List(0));
    await tester.pump();
    await tester.pump();

    expect(formats, [PdfPageFormat.a4, PdfPageFormat.a5]);
  });
}
