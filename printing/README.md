# Printing

A plugin that allows Flutter apps to generate and print
documents to android or ios compatible printers

See the example on how to use the plugin.

<img alt="Example document" src="https://raw.githubusercontent.com/DavBfr/dart_pdf/master/printing/example.png" width="300">

This example is also available on the web here: <https://davbfr.github.io/dart_pdf/>.

This plugin uses the `pdf` package <https://pub.dev/packages/pdf>
for pdf creation. Please refer to <https://pub.dev/documentation/pdf/latest/>
for documentation.

[![Buy Me A Coffee](https://bmc-cdn.nyc3.digitaloceanspaces.com/BMC-button-images/custom_images/orange_img.png "Buy Me A Coffee")](https://www.buymeacoffee.com/JORBmbw9h "Buy Me A Coffee")

Example:

```dart
final pdf = Document();

pdf.addPage(Page(
      pageFormat: PdfPageFormat.a4,
      build: (Context context) {
        return Center(
          child: Text("Hello World"),
        ); // Center
      })); // Page
```

To load an image from an ImageProvider:

```dart
const imageProvider = const AssetImage('assets/image.png');
final PdfImage image = await pdfImageFromImageProvider(pdf: pdf.document, image: imageProvider);

pdf.addPage(Page(
    build: (Context context) {
      return Center(
        child: Image(image),
      ); // Center
    })); // Page
```

To use a TrueType font from a flutter bundle:

```dart
final font = await rootBundle.load("assets/open-sans.ttf");
final ttf = Font.ttf(font);

pdf.addPage(Page(
    build: (Context context) {
      return Center(
        child: Text('Dart is awesome', style: TextStyle(font: ttf, fontSize: 40)),
      ); // Center
    })); // Page
```

To save the pdf file using the [path_provider](https://pub.dev/packages/path_provider) library:

```dart
final output = await getTemporaryDirectory();
final file = File("${output.path}/example.pdf");
await file.writeAsBytes(pdf.save());
```

You can also print the document using the iOS or Android print service:

```dart
await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save());
```

Or share the document to other applications:

```dart
await Printing.sharePdf(bytes: pdf.save(), filename: 'my-document.pdf');
```

To print an HTML document:

```dart
await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
          format: format,
          html: '<html><body><p>Hello!</p></body></html>',
        ));
```

Convert a Pdf to images, one image per page, get only pages 1 and 2 at 72 dpi:

```dart
await for (var page in Printing.raster(pdf.save(), pages: [0, 1], dpi: 72)) {
  final image = page.toImage();
  // ...or page.toPng()
}
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
       minSdkVersion 21  // <-- Change this line to 21 or more
       ...
   }
   ```
