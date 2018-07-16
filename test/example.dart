import 'dart:io';

import 'package:pdf/pdf.dart';

void main() {
  final pdf = new PDFDocument();
  final page = new PDFPage(pdf, pageFormat: new PDFPageFormat(PDFPageFormat.LETTER));
  final g = page.getGraphics();
  final font = new PDFFont(pdf);

  g.setColor(new PDFColor(0.0, 1.0, 1.0));
  g.drawRect(50.0, 30.0, 100.0, 50.0);
  g.fillPath();

  g.setColor(new PDFColor(0.3, 0.3, 0.3));
  g.drawString(font, 12.0, "Hello World!", 50.0, 300.0);

  var file = new File('file.pdf');
  file.writeAsBytesSync(pdf.save());
}
