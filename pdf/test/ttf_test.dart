import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('Pdf', () {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));

    var g = page.getGraphics();
    var ttf = PdfTtfFont(
        pdf,
        (File("open-sans.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());
    var s = "Hello World!";
    var r = ttf.stringBounds(s);
    const FS = 20.0;
    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 30.0 + r.y * FS, r.w * FS, r.h * FS);
    g.fillPath();
    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(ttf, FS, s, 50.0, 30.0);

    var roboto = PdfTtfFont(
        pdf,
        (File("roboto.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());

    r = roboto.stringBounds(s);
    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 130.0 + r.y * FS, r.w * FS, r.h * FS);
    g.fillPath();
    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(roboto, FS, s, 50.0, 130.0);

    var noto = PdfTtfFont(
        pdf,
        (File("noto-sans.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());

    s = "你好世界";
    r = noto.stringBounds(s);
    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 80.0 + r.y * FS, r.w * FS, r.h * FS);
    g.fillPath();
    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(noto, FS, s, 50.0, 80.0);

    var file = File('file2.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
