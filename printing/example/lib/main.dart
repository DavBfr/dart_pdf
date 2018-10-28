import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:printing_example/document.dart';

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

  void _printPdf() async {
    print("Print ...");
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async =>
            (await generateDocument(format)).save());
  }

  void _sharePdf() async {
    print("Share ...");
    final pdf = await generateDocument(PdfPageFormat.a4);

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
    RenderRepaintBoundary boundary =
        previewContainer.currentContext.findRenderObject();
    final im = await boundary.toImage();
    final bytes = await im.toByteData(format: ImageByteFormat.rawRgba);
    print("Print Screen ${im.width}x${im.height} ...");

    Printing.layoutPdf(onLayout: (PdfPageFormat format) {
      final pdf = PdfDocument(deflate: zlib.encode);
      final page = PdfPage(pdf, pageFormat: format);
      final g = page.getGraphics();

      // Center the image
      final w = page.pageFormat.width -
          page.pageFormat.marginLeft -
          page.pageFormat.marginRight;
      final h = page.pageFormat.height -
          page.pageFormat.marginTop -
          page.pageFormat.marginBottom;
      double iw, ih;
      if (im.width.toDouble() / im.height.toDouble() < 1.0) {
        ih = h;
        iw = im.width.toDouble() * ih / im.height.toDouble();
      } else {
        iw = w;
        ih = im.height.toDouble() * iw / im.width.toDouble();
      }

      PdfImage image = PdfImage(pdf,
          image: bytes.buffer.asUint8List(),
          width: im.width,
          height: im.height);
      g.drawImage(
          image,
          page.pageFormat.marginLeft + (w - iw) / 2.0,
          page.pageFormat.height -
              page.pageFormat.marginTop -
              ih -
              (h - ih) / 2.0,
          iw,
          ih);

      return pdf.save();
    });
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
