# Pdf creation library for dart / flutter

This is a low-level Pdf creation library.
It can create a full multi-pages document with graphics,
images and text using TrueType fonts.

> Use `printing` package <https://pub.dartlang.org/packages/printing>
> for full flutter print and share operation.

The coordinate system is using the internal Pdf system:
 * (0.0, 0.0) is bottom-left
 * 1.0 is defined as 1 / 72.0 inch
 * you can use the constants for centimeters, milimeters and inch defined in PdfPageFormat

Example:
```dart
final pdf = PdfDocument();
final page = PdfPage(pdf, pageFormat: PdfPageFormat.letter);
final g = page.getGraphics();
final font = PdfFont(pdf);

g.setColor(PdfColor(0.0, 1.0, 1.0));
g.drawRect(50.0, 30.0, 100.0, 50.0);
g.fillPath();

g.setColor(PdfColor(0.3, 0.3, 0.3));
g.drawString(font, 12.0, "Hello World!", 5.0 * PdfPageFormat.mm, 300.0);

var file = File('file.pdf');
file.writeAsBytesSync(pdf.save());
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
