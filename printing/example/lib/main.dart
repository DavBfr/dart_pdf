import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  final shareWidget = GlobalKey();
  final previewContainer = GlobalKey();

  PdfDocument _generateDocument() {
    final pdf = PdfDocument(deflate: zlib.encode);
    final page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);
    final g = page.getGraphics();
    final font = PdfFont.helvetica(pdf);
    final top = page.pageFormat.height;

    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 * PdfPageFormat.mm, top - 80.0 * PdfPageFormat.mm,
        100.0 * PdfPageFormat.mm, 50.0 * PdfPageFormat.mm);
    g.fillPath();

    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(font, 12.0, "Hello World!", 10.0 * PdfPageFormat.mm,
        top - 10.0 * PdfPageFormat.mm);

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
    final bounds = Rect.fromPoints(topLeft, bottomRight);

    Printing.sharePdf(document: pdf, bounds: bounds);
  }

  Future<void> _printScreen() async {
    const margin = 10.0 * PdfPageFormat.mm;
    final pdf = PdfDocument(deflate: zlib.encode);
    final page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);
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

    PdfImage image = PdfImage(pdf,
        image: bytes.buffer.asUint8List(), width: im.width, height: im.height);
    g.drawImage(image, margin + (w - iw) / 2.0,
        page.pageFormat.height - margin - ih - (h - ih) / 2.0, iw, ih);

    Printing.printPdf(document: pdf);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        key: previewContainer,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Pdf Printing Example'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                RaisedButton(
                    child: Text('Print Document'), onPressed: _printPdf),
                RaisedButton(
                    key: shareWidget,
                    child: Text('Share Document'),
                    onPressed: _sharePdf),
                RaisedButton(
                    child: Text('Print Screenshot'), onPressed: _printScreen),
              ],
            ),
          ),
        ));
  }
}
