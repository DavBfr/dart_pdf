# Pdf creation library for dart / flutter

This is a low-level Pdf creation library.
It can create a full multi-pages document with graphics,
images and text using TrueType fonts.

> Use `printing` package <https://pub.dartlang.org/packages/printing>
> for full flutter print and share operation.

The coordinate system is using the internal Pdf system:
 * (0.0, 0.0) is bottom-left
 * 1.0 is defined as 1 / 72.0 inch
 * you can use the constants for centimeters, milimeters and inch defined in PDFPageFormat

Example:
```dart
final pdf = new PDFDocument();
final page = new PDFPage(pdf, pageFormat: PDFPageFormat.LETTER);
final g = page.getGraphics();
final font = new PDFFont(pdf);

g.setColor(new PDFColor(0.0, 1.0, 1.0));
g.drawRect(50.0, 30.0, 100.0, 50.0);
g.fillPath();

g.setColor(new PDFColor(0.3, 0.3, 0.3));
g.drawString(font, 12.0, "Hello World!", 5.0 * PDFPageFormat.MM, 300.0);

var file = new File('file.pdf');
file.writeAsBytesSync(pdf.save());
```

To load an image it is possible to use the dart library [image](https://pub.dartlang.org/packages/image):

```dart
Image image = decodeImage(new Io.File('test.webp').readAsBytesSync());
PDFImage image = new PDFImage(
  pdf,
	image: img.data.buffer.asUint8List(),
	width: img.width,
	height: img.height);
g.drawImage(image, 100.0, 100.0, 80.0);
```

To use a TrueType font:

```dart
PDFTTFFont ttf = new PDFTTFFont(
  pdf,
  (new File("open-sans.ttf").readAsBytesSync() as Uint8List).buffer.asByteData());
g.setColor(new PDFColor(0.3, 0.3, 0.3));
g.drawString(ttf, 20.0, "Dart is awesome", 50.0, 30.0);
```
