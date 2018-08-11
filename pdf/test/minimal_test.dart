import 'dart:io';

import 'package:pdf/pdf.dart';
import "package:test/test.dart";

void main() {
  test('Pdf1', () {
    var pdf = new PDFDocument(deflate: false);
    var page = new PDFPage(pdf, pageFormat: PDFPageFormat.A4);

    var g = page.getGraphics();
    g.drawLine(30.0, 30.0, 200.0, 200.0);
    g.strokePath();

    var file = new File('file1.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
