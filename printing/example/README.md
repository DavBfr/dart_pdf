# Pdf Printing Example

```dart
void printPdf() {
  Printing.layoutPdf(onLayout: (PdfPageFormat format) {
    final pdf = Document()
      ..addPage(Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) {
            return Center(
              child: Text("Hello World"),
            ); // Center
          }));
    return pdf.save();
  }); // Page
}
```
