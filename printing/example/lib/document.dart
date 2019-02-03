import 'dart:io';
import 'dart:async';

import 'package:pdf/pdf.dart';

Future<PdfDocument> generateDocument(PdfPageFormat format) async {
  final pdf = PdfDocument(deflate: zlib.encode);
  final page = PdfPage(pdf,
      pageFormat: format.applyMargin(
          left: 2.0 * PdfPageFormat.cm,
          top: 2.0 * PdfPageFormat.cm,
          right: 2.0 * PdfPageFormat.cm,
          bottom: 2.0 * PdfPageFormat.cm));
  final g = page.getGraphics();
  final font = PdfFont.helvetica(pdf);
  final top = page.pageFormat.height - page.pageFormat.marginTop;

  g.setColor(PdfColor.orange);
  g.drawRect(
      page.pageFormat.marginLeft,
      page.pageFormat.marginBottom,
      page.pageFormat.width -
          page.pageFormat.marginRight -
          page.pageFormat.marginLeft,
      page.pageFormat.height -
          page.pageFormat.marginTop -
          page.pageFormat.marginBottom);
  g.strokePath();

  g.setColor(PdfColor(0.0, 1.0, 1.0));
  g.drawRRect(
    50.0 * PdfPageFormat.mm,
    top - 80.0 * PdfPageFormat.mm,
    100.0 * PdfPageFormat.mm,
    50.0 * PdfPageFormat.mm,
    20.0,
    20.0,
  );
  g.fillPath();

  g.setColor(PdfColor(0.3, 0.3, 0.3));
  g.drawString(
      font,
      12.0,
      "Hello World!",
      page.pageFormat.marginLeft + 10.0 * PdfPageFormat.mm,
      top - 10.0 * PdfPageFormat.mm);

  {
    final page = PdfPage(pdf,
        pageFormat: format.applyMargin(
            left: 2.0 * PdfPageFormat.cm,
            top: 2.0 * PdfPageFormat.cm,
            right: 2.0 * PdfPageFormat.cm,
            bottom: 2.0 * PdfPageFormat.cm));
    final g = page.getGraphics();
    final font = PdfFont.helvetica(pdf);
    final top = page.pageFormat.height - page.pageFormat.marginTop;

    g.setColor(PdfColor.orange);
    g.drawRect(
        page.pageFormat.marginLeft,
        page.pageFormat.marginBottom,
        page.pageFormat.width -
            page.pageFormat.marginRight -
            page.pageFormat.marginLeft,
        page.pageFormat.height -
            page.pageFormat.marginTop -
            page.pageFormat.marginBottom);
    g.strokePath();

    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRRect(
      50.0 * PdfPageFormat.mm,
      top - 80.0 * PdfPageFormat.mm,
      100.0 * PdfPageFormat.mm,
      50.0 * PdfPageFormat.mm,
      20.0,
      20.0,
    );
    g.fillPath();

    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(
        font,
        12.0,
        "Hello World!",
        page.pageFormat.marginLeft + 10.0 * PdfPageFormat.mm,
        top - 10.0 * PdfPageFormat.mm);
  }
  return pdf;
}
