# Pdf creation library for dart/flutter

This library is divided into two parts:

- a low-level Pdf creation library that takes care of the pdf bits generation.
- a Widgets system similar to Flutter's, for easy high-level Pdf creation.

It can create a full multi-pages document with graphics,
images, and text using TrueType fonts. With the ease of use you already know.

See an interactive demo here: <https://davbfr.github.io/dart_pdf/>.

<a href="https://davbfr.github.io/dart_pdf/">
<img alt="Example document" src="https://raw.githubusercontent.com/DavBfr/dart_pdf/master/pdf/example.jpg">
</a>

The source code for a full demo that can run on any Flutter target, and how to build,
it can be found here:
<https://github.com/DavBfr/dart_pdf/tree/master/demo/>

Use the `printing` package <https://pub.dev/packages/printing>
for full flutter print and share operation.

The coordinate system is using the internal Pdf unit:

- 1.0 is defined as 1 / 72.0 inch
- you can use the constants for centimeters, millimeters, and inch defined in PdfPageFormat

[![Buy Me A Coffee](https://bmc-cdn.nyc3.digitaloceanspaces.com/BMC-button-images/custom_images/orange_img.png "Buy Me A Coffee")](https://www.buymeacoffee.com/JORBmbw9h "Buy Me A Coffee")

## Installing

If you want to print the Pdf document on an actual printer with Flutter,
follow the instructions at <https://pub.dev/packages/printing>

1. Add this package to your package's `pubspec.yaml` file as described
   on the installation tab

2. Import the libraries

   ```dart
   import 'package:pdf/pdf.dart';
   import 'package:pdf/widgets.dart' as pw;
   ```

## Examples

```dart
final pdf = pw.Document();

pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Text("Hello World"),
        ); // Center
      })); // Page
```

To load an image from a file (Mobile):

```dart
final image = pw.MemoryImage(
  File('test.webp').readAsBytesSync(),
);

pdf.addPage(pw.Page(build: (pw.Context context) {
  return pw.Center(
    child: pw.Image(image),
  ); // Center
})); // Page
```

To load an image from asset file (web):

Create a Uint8List from the image

```dart
final img = await rootBundle.load('assets/images/logo.jpg');
final imageBytes = img.buffer.asUint8List();
```
Create an image from the ImageBytes

```dart
pw.Image image = pw.Image(pw.MemoryImage(imageBytes));
```
implement the image in a container
```dart
pw.Container(
   alignment: pw.Alignment.center,
   height: 200,
   child: image,
),
```

To load an image from the network using the `printing` package:

```dart
final netImage = await networkImage('https://www.nfet.net/nfet.jpg');

pdf.addPage(pw.Page(build: (pw.Context context) {
  return pw.Center(
    child: pw.Image(netImage),
  ); // Center
})); // Page
```

To load an SVG:

```dart
String svgRaw = '''
<svg viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg">
  <ellipse style="fill: grey; stroke: black;" cx="25" cy="25" rx="20" ry="20"></ellipse>
</svg>
''';

final svgImage = pw.SvgImage(svg: svgRaw);

pdf.addPage(pw.Page(build: (pw.Context context) {
  return pw.Center(
    child: svgImage,
  ); // Center
})); // Page
```

To load the SVG from a Flutter asset, use `await rootBundle.loadString('assets/file.svg')`

To use a TrueType font:

```dart
final Uint8List fontData = File('open-sans.ttf').readAsBytesSync();
final ttf = pw.Font.ttf(fontData.buffer.asByteData());

pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return pw.Center(
        child: pw.Text('Hello World', style: pw.TextStyle(font: ttf, fontSize: 40)),
      ); // Center
    })); // Page
```

Or using the `printing` package's `PdfGoogleFonts`:

```dart
final font = await PdfGoogleFonts.nunitoExtraLight();

pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return pw.Center(
        child: pw.Text('Hello World', style: pw.TextStyle(font: font, fontSize: 40)),
      ); // Center
    })); // Page
```

To display emojis:

```dart
final emoji = await PdfGoogleFonts.notoColorEmoji();

pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) {
      return pw.Center(
        child: pw.Text(
          'Hello 🐒💁👌🎍😍🦊👨 world!',
          style: pw.TextStyle(
            fontFallback: [emoji],
            fontSize: 25,
          ),
        ),
      ); // Center
    })); // Page
```

To save the pdf file (Mobile):

```dart
// On Flutter, use the [path_provider](https://pub.dev/packages/path_provider) library:
//   final output = await getTemporaryDirectory();
//   final file = File("${output.path}/example.pdf");
final file = File("example.pdf");
await file.writeAsBytes(await pdf.save());
```

To save the pdf file (Web):
(saved as a unique name based on milliseconds since epoch)

```dart
var savedFile = await pdf.save();
List<int> fileInts = List.from(savedFile);
html.AnchorElement(
    href: "data:application/octet-stream;charset=utf-16le;base64,${con.base64.encode(fileInts)}")
  ..setAttribute("download", "${DateTime.now().millisecondsSinceEpoch}.pdf")
  ..click();
```

## Encryption, Digital Signature, and loading a PDF Document

Encryption using RC4-40, RC4-128, AES-128, and AES-256 is fully supported using a separate library.
This library also provides SHA1 or SHA-256 Digital Signature using your x509 certificate. The graphic signature is represented by a clickable widget that shows Digital Signature information.
It implements a PDF parser to load an existing document and add pages, change pages, and add a signature.

More information here: <https://pub.nfet.net/pdf_crypto/>
