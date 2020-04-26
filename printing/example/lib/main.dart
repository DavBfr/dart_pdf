// ignore_for_file: always_specify_types

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const title = 'Printing Demo';

    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(title),
        ),
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printDocument,
          ),
        ),
      ),
    );
  }

  void _printDocument() {
    Printing.layoutPdf(
      onLayout: (pageFormat) {
        final doc = pw.Document();

        doc.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Center(
              child: pw.Text('Hello World!'),
            ),
          ),
        );

        return doc.save();
      },
    );
  }
}
