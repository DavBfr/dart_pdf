# Pdf Printing Example

```dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as Pdf;
import 'package:printing/printing.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Printing Demo'),
        ),
        body: Center(
          child: FlatButton(
            child: Text("Print Document"),
            onPressed: () {
              Printing.layoutPdf(onLayout: buildPdf);
            },
          ),
        ),
      ),
    );
  }

  List<int> buildPdf(PdfPageFormat format) {
    final PdfDoc pdf = PdfDoc()
      ..addPage(Pdf.Page(
          pageFormat: format,
          build: (Pdf.Context context) {
            return Pdf.ConstrainedBox(
              constraints: const Pdf.BoxConstraints.expand(),
              child: Pdf.FittedBox(
                  child: Pdf.Text(
                "Hello World",
              )),
            );
          }));
    return pdf.save();
  }
}
```
