import 'dart:io';

import 'package:pdf/pdf.dart';

void main() {
  final pdf = new PDFDocument(deflate: zlib.encode);
  final page = new PDFPage(pdf, pageFormat: PDFPageFormat.letter);
  final g = page.getGraphics();
  final font = new PDFFont(pdf);
  final top = page.pageFormat.height;

  g.setColor(new PDFColor(0.0, 1.0, 1.0));
  g.drawRect(50.0 * PDFPageFormat.mm, top - 80.0 * PDFPageFormat.mm,
      100.0 * PDFPageFormat.mm, 50.0 * PDFPageFormat.mm);
  g.fillPath();

  g.setColor(new PDFColor(0.3, 0.3, 0.3));
  g.drawString(font, 12.0, "Hello World!", 10.0 * PDFPageFormat.mm,
      top - 10.0 * PDFPageFormat.mm);

  var file = new File('example.pdf');
  file.writeAsBytesSync(pdf.save());
}
