import 'dart:io';

import 'package:pdf/pdf.dart';

void main() {
  final pdf = new PdfDocument(deflate: zlib.encode);
  final page = new PdfPage(pdf, pageFormat: PdfPageFormat.letter);
  final g = page.getGraphics();
  final font = new PdfFont(pdf);
  final top = page.pageFormat.height;

  g.setColor(new PdfColor(0.0, 1.0, 1.0));
  g.drawRect(50.0 * PdfPageFormat.mm, top - 80.0 * PdfPageFormat.mm,
      100.0 * PdfPageFormat.mm, 50.0 * PdfPageFormat.mm);
  g.fillPath();

  g.setColor(new PdfColor(0.3, 0.3, 0.3));
  g.drawString(font, 12.0, "Hello World!", 10.0 * PdfPageFormat.mm,
      top - 10.0 * PdfPageFormat.mm);

  var file = new File('example.pdf');
  file.writeAsBytesSync(pdf.save());
}
