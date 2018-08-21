import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('Pdf', () {
    var pdf = new PDFDocument();
    var i = pdf.info;
    i.author = "David PHAM-VAN";
    i.creator = i.author;
    i.title = "My Title";
    i.subject = "My Subject";
    var page = new PDFPage(pdf, pageFormat: const PDFPageFormat(500.0, 300.0));

    var g = page.getGraphics();
    var ttf = new PDFTTFFont(
        pdf,
        (new File("open-sans.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());
    var s = "Hello World!";
    var r = ttf.stringBounds(s);
    print(r);
    const FS = 20.0;
    g.setColor(new PDFColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 30.0 + r.y * FS, r.w * FS, r.h * FS);
    g.fillPath();
    g.setColor(new PDFColor(0.3, 0.3, 0.3));
    g.drawString(ttf, FS, s, 50.0, 30.0);

    var file = new File('file2.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
