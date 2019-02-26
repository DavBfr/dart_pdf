# Printing

Plugin that allows Flutter apps to generate and print
documents to android or ios compatible printers

See the example on how to use the plugin.

<img alt="Example document" src="https://raw.githubusercontent.com/DavBfr/dart_pdf/master/printing/example.png" width="300">

> This plugin uses the `pdf` package <https://pub.dartlang.org/packages/pdf>
> for pdf creation. Please refer to <https://pub.dartlang.org/documentation/pdf/latest/>
> for documentation.

To load an image it is possible to use
[Image.toByteData](https://docs.flutter.io/flutter/dart-ui/Image/toByteData.html):

```dart
var Image im;
var bytes = await im.toByteData(format: ui.ImageByteFormat.rawRgba);

PdfImage image = PdfImage(
    pdf,
    image: bytes.buffer.asUint8List(), 
    width: im.width, 
    height: im.height);
g.drawImage(image, 100.0, 100.0, 80.0);
```

To use a TrueType font from a flutter bundle:

```dart
var font = await rootBundle.load("assets/open-sans.ttf");
PdfTtfFont ttf = PdfTtfFont(pdf, font);
g.setColor(PdfColor(0.3, 0.3, 0.3));
g.drawString(ttf, 20.0, "Dart is awesome", 50.0, 30.0);
```

## Installing

1. Add this to your package's `pubspec.yaml` file:

   ```yaml
   dependencies:
     printing: any       # <-- Add this line
   ```

2. Enable Swift on the iOS project, in `ios/Podfile`:

   ```Ruby
   target 'Runner' do
      use_frameworks!    # <-- Add this line
   ```

3. Set minimum Android version in `android/app/build.gradle`:

   ```java
   defaultConfig {
       ...
       minSdkVersion 19  // <-- Change this line to 19 or more
       ...
   }
   ```
