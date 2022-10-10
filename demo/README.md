# Pdf Printing Example

This is a highly detailed example of the many features of the PDF library 
embedded in a flutter application. This application shows among other things:
* How to embed the PDF render in your application
* How to enable printing, sharing, and saving PDFs from your application
* How to do full page layout and content generation including:
  * Embedding fonts
  * Embedding graphics
  * Generating QR codes
  * Using drawing primitives
  * Generating charts and tables


### Instructions 
The easiest way to run this on any of the
available Flutter target platforms is to check out the main project repository,
run the Makefile to get the needed assets, and then run the demo program.
Linux and macOS should be configured with Make already. 
To get this working on Windows you will need to install GNU Make if it isn't already. 
The easiest way to get this setup is to 
install [The Chocolatey Software Manager](https://chocolatey.org/) and then
execute:

```bash
choco install make
```

With that installed the steps to get this running for your target platform 
will be:

Check out the source code from the repository:
```bash
git clone https://github.com/DavBfr/dart_pdf.git
```

Navigate to the directory and install the font and graphics assets:

```bash
cd dart_pdf
make get-all
```

Next go into the demo source folder and run the program. Such as for Windows:

```bash
flutter run -d windows
```

...for Linux:
```bash
flutter run -d linux
```

...for macOS:
```bash
flutter run -d macos
```


### Dart PDF Hello World

```dart
import 'package:flutter/material.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.print),
          tooltip: 'Print Document',
          onPressed: () {
            // This is where we print the document
            Printing.layoutPdf(
              // [onLayout] will be called multiple times
              // when the user changes the printer or printer settings
              onLayout: (PdfPageFormat format) {
                // Any valid Pdf document can be returned here as a list of int
                return buildPdf(format);
              },
            );
          },
        ),
        body: Center(
          child: Text('Click on the print button below'),
        ),
      ),
    );
  }

  /// This method takes a page format and generates the Pdf file data
  Future<Uint8List> buildPdf(PdfPageFormat format) async {
    // Create the Pdf document
    final pw.Document doc = pw.Document();

    // Add one page with centered text "Hello World"
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.ConstrainedBox(
            constraints: pw.BoxConstraints.expand(),
            child: pw.FittedBox(
              child: pw.Text('Hello World'),
            ),
          );
        },
      ),
    );

    // Build and return the final Pdf file data
    return await doc.save();
  }
}
```
