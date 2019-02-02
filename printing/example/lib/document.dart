import 'dart:io';
import 'dart:async';

import 'package:pdf/pdf.dart';

Future<PdfDocument> generateDocument() async {
  final pdf = PdfDocument(deflate: zlib.encode);
  final page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);
  final g = page.getGraphics();
  final font = PdfFont.helvetica(pdf);
  final top = page.pageFormat.height;

  g.setColor(PdfColor(0.0, 1.0, 1.0));
  g.drawRect(50.0 * PdfPageFormat.mm, top - 80.0 * PdfPageFormat.mm,
      100.0 * PdfPageFormat.mm, 50.0 * PdfPageFormat.mm);
  g.fillPath();

  g.setColor(PdfColor(0.3, 0.3, 0.3));
  g.drawString(font, 12.0, "Hello World!", 10.0 * PdfPageFormat.mm,
      top - 10.0 * PdfPageFormat.mm);

  return pdf;
}
