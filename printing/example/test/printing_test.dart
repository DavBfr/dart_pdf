import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing_example/document.dart';

void main() {
  testWidgets('Pdf Generate the document', (WidgetTester tester) async {
    final Document document = await generateDocument(PdfPageFormat.a4);

    final File file = File('document.pdf');
    file.writeAsBytesSync(document.save());
  });
}
