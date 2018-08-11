import 'dart:io';

import 'package:pdf/pdf.dart';

void main() {
  final pdf = new PDFDocument();
  final page = new PDFPage(pdf, pageFormat: PDFPageFormat.LETTER);
  final g = page.getGraphics();
  final font = new PDFFont(pdf);
  final top = page.pageFormat.height;

  g.setColor(new PDFColor(0.0, 1.0, 1.0));
  g.drawRect(50.0 * PDFPageFormat.MM, top - 80.0 * PDFPageFormat.MM, 100.0 * PDFPageFormat.MM,
      50.0 * PDFPageFormat.MM);
  g.fillPath();

  g.setColor(new PDFColor(0.3, 0.3, 0.3));
  g.drawString(
      font, 12.0, "Hello World!", 10.0 * PDFPageFormat.MM, top - 10.0 * PDFPageFormat.MM);

  var file = new File('example.pdf');
  file.writeAsBytesSync(pdf.save());
}
