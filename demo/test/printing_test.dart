import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing_demo/document.dart';

void main() {
  testWidgets('Pdf Generate the document', (WidgetTester tester) async {
    final doc = await generateDocument(PdfPageFormat.a4);

    final file = File('document.pdf');
    file.writeAsBytesSync(doc);
  });
}
