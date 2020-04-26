// ignore_for_file: always_specify_types

import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

void main() {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      build: (pw.Context context) => pw.Center(
        child: pw.Text('Hello World!'),
      ),
    ),
  );

  final file = File('example.pdf');
  file.writeAsBytesSync(doc.save());
}
