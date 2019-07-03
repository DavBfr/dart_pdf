# Pdf Printing Example

```dart
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Printing Demo'),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.print),
          tooltip: 'Print Document',
          onPressed: () {
            Printing.layoutPdf(
              onLayout: buildPdf,
            );
          },
        ),
        body: Center(
          child: const Text('Click on the print button below'),
        ),
      ),
    );
  }

  List<int> buildPdf(PdfPageFormat format) {
    final Document doc = Document();

    doc.addPage(
      pdf.Page(
        pageFormat: format,
        build: (pdf.Context context) {
          return pdf.ConstrainedBox(
            constraints: const pdf.BoxConstraints.expand(),
            child: pdf.FittedBox(
              child: pdf.Text(
                'Hello World',
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
```
