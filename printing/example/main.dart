import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() => runApp(new MaterialApp(home: new MyApp()));

class MyApp extends StatelessWidget {
  final shareWidget = new GlobalKey();

  PDFDocument _generateDocument() {
    final pdf = new PDFDocument(deflate: zlib.encode);
    final page = new PDFPage(pdf, pageFormat: PDFPageFormat.A4);
    final g = page.getGraphics();
    final font = new PDFFont(pdf);
    final top = page.pageFormat.height;

    g.setColor(new PDFColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 * PDFPageFormat.MM, top - 80.0 * PDFPageFormat.MM,
        100.0 * PDFPageFormat.MM, 50.0 * PDFPageFormat.MM);
    g.fillPath();

    g.setColor(new PDFColor(0.3, 0.3, 0.3));
    g.drawString(font, 12.0, "Hello World!", 10.0 * PDFPageFormat.MM,
        top - 10.0 * PDFPageFormat.MM);

    return pdf;
  }

  void _printPdf() {
    print("Print ...");
    final pdf = _generateDocument();
    Printing.printPdf(document: pdf);
  }

  void _sharePdf() {
    print("Share ...");
    final pdf = _generateDocument();

    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox =
        shareWidget.currentContext.findRenderObject();
    final topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final bounds = new Rect.fromPoints(topLeft, bottomRight);

    Printing.sharePdf(document: pdf, bounds: bounds);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text('Printing example'),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new RaisedButton(
                child: new Text('Print Document'), onPressed: _printPdf),
            new RaisedButton(
                key: shareWidget,
                child: new Text('Share Document'),
                onPressed: _sharePdf),
          ],
        ),
      ),
    );
  }
}
