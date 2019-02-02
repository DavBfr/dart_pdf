import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:printing_example/document.dart';

void main() {
  testWidgets('Generate the Pdf document', (WidgetTester tester) async {
    final pdf = await generateDocument();
    var file = File('document.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
