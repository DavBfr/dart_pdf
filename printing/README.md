# Printing

Plugin that allows Flutter apps to generate and print
documents to android or ios compatible printers

See the example on how to use the plugin.

> This plugin uses the `pdf` package <https://pub.dartlang.org/packages/pdf>
> for pdf creation. Please refer to <https://pub.dartlang.org/documentation/pdf/latest/>
> for documentation.

To load an image it is possible to use
[Image.toByteData](https://docs.flutter.io/flutter/dart-ui/Image/toByteData.html):

```dart
var Image im;
var bytes = await im.toByteData(format: ui.ImageByteFormat.rawRgba);

PDFImage image = PDFImage(
    pdf,
    image: bytes.buffer.asUint8List(), 
    width: im.width, 
    height: im.height);
g.drawImage(image, 100.0, 100.0, 80.0);
```

To use a TrueType font from a flutter bundle:

```dart
var font = await rootBundle.load("assets/open-sans.ttf");
PDFTTFFont ttf = new PDFTTFFont(pdf, font);
g.setColor(new PDFColor(0.3, 0.3, 0.3));
g.drawString(ttf, 20.0, "Dart is awesome", 50.0, 30.0);
```
