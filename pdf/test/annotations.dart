import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('Pdf', () {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));
    var page1 = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));

    var g = page.getGraphics();

    PdfAnnot.text(page,
        content: "Hello", rect: PdfRect(100.0, 100.0, 50.0, 50.0));

    PdfAnnot.link(page,
        dest: page1, srcRect: PdfRect(100.0, 150.0, 50.0, 50.0));
    g.drawRect(100.0, 150.0, 50.0, 50.0);
    g.strokePath();

    var file = File('annot.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
