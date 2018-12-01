import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Pdf', () {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));

    page.annotations.add(PdfAnnot.annotation(page, "Hello", PdfRect(100.0, 100.0, 50.0, 50.0)));

    var file = File('annot.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
