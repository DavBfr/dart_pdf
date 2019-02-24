# Pdf creation library for dart / flutter

This library is divided in two parts:

* a low-level Pdf creation library that takes care of the pdf bits generation.
* a Widgets system similar to Flutter's, for easy high-level Pdf creation.

It can create a full multi-pages document with graphics,
images and text using TrueType fonts. With the ease of use you already know.

<img alt="Example document" src="https://raw.githubusercontent.com/DavBfr/dart_pdf/master/pdf/example.jpg">

> Use the `printing` package <https://pub.dartlang.org/packages/printing>
> for full flutter print and share operation.

The coordinate system is using the internal Pdf unit:
 * 1.0 is defined as 1 / 72.0 inch
 * you can use the constants for centimeters, milimeters and inch defined in PdfPageFormat

Example:
```dart
final pdf = Document()
  ..addPage(Page(
      pageFormat: PdfPageFormat.a4,
      build: (Context context) {
        return Center(
          child: Text("Hello World"),
        ); // Center
      })); // Page
```

To load an image it is possible to use the dart library [image](https://pub.dartlang.org/packages/image):

```dart
Image image = decodeImage(Io.File('test.webp').readAsBytesSync());
PdfImage image = PdfImage(
  pdf,
	image: img.data.buffer.asUint8List(),
	width: img.width,
	height: img.height);
g.drawImage(image, 100.0, 100.0, 80.0);
```

To use a TrueType font:

```dart
PdfTtfFont ttf = PdfTtfFont(
  pdf,
  (File("open-sans.ttf").readAsBytesSync() as Uint8List).buffer.asByteData());
g.setColor(PdfColor(0.3, 0.3, 0.3));
g.drawString(ttf, 20.0, "Dart is awesome", 50.0, 30.0);
```

To save the image on Flutter, use the [path_provider](https://pub.dartlang.org/packages/path_provider) library:

```dart
Directory tempDir = await getTemporaryDirectory();
String tempPath = tempDir.path;
var file = File("$tempPath/file.pdf");
await file.writeAsBytes(pdf.save());
```
