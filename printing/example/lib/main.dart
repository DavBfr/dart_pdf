import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() => runApp(new MaterialApp(home: new MyApp()));

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return new MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  final shareWidget = new GlobalKey();
  final previewContainer = new GlobalKey();

  PDFDocument _generateDocument() {
    final pdf = new PDFDocument(deflate: zlib.encode);
    final page = new PDFPage(pdf, pageFormat: PDFPageFormat.a4);
    final g = page.getGraphics();
    final font = new PDFFont(pdf);
    final top = page.pageFormat.height;

    g.setColor(new PDFColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 * PDFPageFormat.mm, top - 80.0 * PDFPageFormat.mm,
        100.0 * PDFPageFormat.mm, 50.0 * PDFPageFormat.mm);
    g.fillPath();

    g.setColor(new PDFColor(0.3, 0.3, 0.3));
    g.drawString(font, 12.0, "Hello World!", 10.0 * PDFPageFormat.mm,
        top - 10.0 * PDFPageFormat.mm);

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

  Future<void> _printScreen() async {
    const margin = 10.0 * PDFPageFormat.mm;
    final pdf = new PDFDocument(deflate: zlib.encode);
    final page = new PDFPage(pdf, pageFormat: PDFPageFormat.a4);
    final g = page.getGraphics();

    RenderRepaintBoundary boundary =
        previewContainer.currentContext.findRenderObject();
    final im = await boundary.toImage();
    final bytes = await im.toByteData(format: ImageByteFormat.rawRgba);
    print("Print Screen ${im.width}x${im.height} ...");

    // Center the image
    final w = page.pageFormat.width - margin * 2.0;
    final h = page.pageFormat.height - margin * 2.0;
    double iw, ih;
    if (im.width.toDouble() / im.height.toDouble() < 1.0) {
      ih = h;
      iw = im.width.toDouble() * ih / im.height.toDouble();
    } else {
      iw = w;
      ih = im.height.toDouble() * iw / im.width.toDouble();
    }

    PDFImage image = PDFImage(pdf,
        image: bytes.buffer.asUint8List(), width: im.width, height: im.height);
    g.drawImage(image, margin + (w - iw) / 2.0,
        page.pageFormat.height - margin - ih - (h - ih) / 2.0, iw, ih);

    Printing.printPdf(document: pdf);
  }

  @override
  Widget build(BuildContext context) {
    return new RepaintBoundary(
        key: previewContainer,
        child: new Scaffold(
          appBar: new AppBar(
            title: const Text('Pdf Printing Example'),
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
                new RaisedButton(
                    child: new Text('Print Screenshot'),
                    onPressed: _printScreen),
              ],
            ),
          ),
        ));
  }
}
