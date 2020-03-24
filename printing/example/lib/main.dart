import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'document.dart';
import 'image_viewer.dart';
import 'viewer.dart';

void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  final GlobalKey<State<StatefulWidget>> shareWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> pickWidget = GlobalKey();
  final GlobalKey<State<StatefulWidget>> previewContainer = GlobalKey();

  Printer selectedPrinter;
  PrintingInfo printingInfo;

  @override
  void initState() {
    Printing.info().then((PrintingInfo info) {
      setState(() {
        printingInfo = info;
      });
    });
    super.initState();
  }

  void _showPrintedToast(bool printed) {
    final ScaffoldState scaffold = Scaffold.of(shareWidget.currentContext);
    if (printed) {
      scaffold.showSnackBar(const SnackBar(
        content: Text('Document printed successfully'),
      ));
    } else {
      scaffold.showSnackBar(const SnackBar(
        content: Text('Document not printed'),
      ));
    }
  }

  Future<void> _printPdf() async {
    print('Print ...');
    try {
      final bool result = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async =>
              (await generateDocument(format)).save());
      _showPrintedToast(result);
    } catch (e) {
      final ScaffoldState scaffold = Scaffold.of(shareWidget.currentContext);
      scaffold.showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
      ));
    }
  }

  Future<void> _saveAsFile() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String appDocPath = appDocDir.path;
    final File file = File(appDocPath + '/' + 'document.pdf');
    print('Save as file ${file.path} ...');
    await file.writeAsBytes((await generateDocument(PdfPageFormat.a4)).save());
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
          builder: (BuildContext context) => PdfViewer(file: file)),
    );
  }

  Future<void> _rasterToImage() async {
    final List<int> doc = (await generateDocument(PdfPageFormat.a4)).save();

    final List<ImageProvider> images = <ImageProvider>[];

    await for (PdfRaster page in Printing.raster(doc)) {
      images.add(PdfRasterImage(page));
    }

    Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
          builder: (BuildContext context) => ImageViewer(images: images)),
    );
  }

  Future<void> _pickPrinter() async {
    print('Pick printer ...');

    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox = pickWidget.currentContext.findRenderObject();
    final Offset topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final Offset bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final Rect bounds = Rect.fromPoints(topLeft, bottomRight);

    try {
      final Printer printer = await Printing.pickPrinter(bounds: bounds);
      print('Selected printer: $selectedPrinter');

      setState(() {
        selectedPrinter = printer;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _directPrintPdf() async {
    print('Direct print ...');
    final bool result = await Printing.directPrintPdf(
        printer: selectedPrinter,
        onLayout: (PdfPageFormat format) async =>
            (await generateDocument(PdfPageFormat.letter)).save());

    _showPrintedToast(result);
  }

  Future<void> _sharePdf() async {
    print('Share ...');
    final pw.Document document = await generateDocument(PdfPageFormat.a4);

    // Calculate the widget center for iPad sharing popup position
    final RenderBox referenceBox =
        shareWidget.currentContext.findRenderObject();
    final Offset topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final Offset bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    final Rect bounds = Rect.fromPoints(topLeft, bottomRight);

    await Printing.sharePdf(
        bytes: document.save(), filename: 'my-résumé.pdf', bounds: bounds);
  }

  Future<void> _printScreen() async {
    final bool result =
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final pw.Document document = pw.Document();

      final PdfImage image = await wrapWidget(
        document.document,
        key: previewContainer,
        pixelRatio: 2.0,
      );

      print('Print Screen ${image.width}x${image.height}...');

      document.addPage(pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Expanded(
                child: pw.Image(image),
              ),
            ); // Center
          })); // Page

      return document.save();
    });

    _showPrintedToast(result);
  }

  Future<void> _printHtml() async {
    print('Print html ...');
    final bool result =
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final String html = await rootBundle.loadString('assets/example.html');
      return await Printing.convertHtml(format: format, html: html);
    });

    _showPrintedToast(result);
  }

  Future<void> _printMarkdown() async {
    print('Print Markdown ...');
    final bool result =
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async {
      final String md = await rootBundle.loadString('assets/example.md');
      final String html = markdown.markdownToHtml(md,
          extensionSet: markdown.ExtensionSet.gitHubWeb);
      return await Printing.convertHtml(format: format, html: html);
    });

    _showPrintedToast(result);
  }

  @override
  Widget build(BuildContext context) {
    bool canDebug = false;
    assert(() {
      canDebug = true;
      return true;
    }());
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
                  child: const Text('Print Document'),
                  onPressed: printingInfo?.canPrint ?? false ? _printPdf : null,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RaisedButton(
                      key: pickWidget,
                      child: const Text('Pick Printer'),
                      onPressed: printingInfo?.directPrint ?? false
                          ? _pickPrinter
                          : null,
                    ),
                    const SizedBox(width: 10),
                    RaisedButton(
                      child: Text(selectedPrinter == null
                          ? 'Direct Print'
                          : 'Print to $selectedPrinter'),
                      onPressed:
                          selectedPrinter != null ? _directPrintPdf : null,
                    ),
                  ],
                ),
                RaisedButton(
                  key: shareWidget,
                  child: const Text('Share Document'),
                  onPressed: printingInfo?.canShare ?? false ? _sharePdf : null,
                ),
                RaisedButton(
                  child: const Text('Print Screenshot'),
                  onPressed: (printingInfo?.canPrint ?? false) && !kIsWeb
                      ? _printScreen
                      : null,
                ),
                RaisedButton(
                  child: const Text('Save to file'),
                  onPressed: kIsWeb ? null : _saveAsFile,
                ),
                RaisedButton(
                  child: const Text('Raster to Image'),
                  onPressed:
                      printingInfo?.canRaster ?? false ? _rasterToImage : null,
                ),
                RaisedButton(
                  child: const Text('Print Html'),
                  onPressed:
                      printingInfo?.canConvertHtml ?? false ? _printHtml : null,
                ),
                RaisedButton(
                  child: const Text('Print Markdown'),
                  onPressed: printingInfo?.canConvertHtml ?? false
                      ? _printMarkdown
                      : null,
                ),
                if (canDebug)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Debug'),
                      Switch.adaptive(
                        onChanged: (bool value) {
                          setState(() {
                            pw.Document.debug = value;
                          });
                        },
                        value: pw.Document.debug,
                      ),
                    ],
                  )
                else
                  const SizedBox(),
              ],
            ),
          ),
        ));
  }
}
