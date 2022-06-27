import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'document.dart';

class Preview{{name.pascalCase()}} extends StatelessWidget {
  const Preview{{name.pascalCase()}}({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const invoice = {{name.pascalCase()}}.demo;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text(invoice.title)),
        body: PdfPreview(
          build: (format) => invoice.buildPdf(format),
          maxPageWidth: 800,
        ),
      ),
    );
  }
}
