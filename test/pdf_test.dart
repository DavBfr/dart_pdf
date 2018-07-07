import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';
import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';


void main() {
  test('Pdf', () {
    Image img = new Image(10, 10);
    img.fill(0x12345678);

    var pdf = new PDFDocument(deflate: false);
    var i = pdf.info;
    i.author = "David PHAM-VAN";
    i.creator = i.author;
    i.title = "My Title";
    i.subject = "My Subject";
    var page = new PDFPage(pdf, pageFormat: new PDFPageFormat([500.0, 300.0]));

    var g = page.getGraphics();
    g.saveContext();
    var tm = new Matrix4.identity();
    tm.translate(100.0, 700.0);
    g.setTransform(tm);
//  g.drawShape("M37 0H9C6.24 0 4 2.24 4 5v38c0 2.76 2.24 5 5 5h28c2.76 0 5-2.24 5-5V5c0-2.76-2.24-5-5-5zM23 46c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm15-8H8V6h30v32z");
    g.restoreContext();
    var font1 = new PDFFont(pdf);

    var font2 = new PDFTTFFont(pdf, new File("../assets/Nunito-Regular.ttf").readAsBytesSync());
    var s = "Hello World!";
    var r = font2.stringBounds(s);
    const FS = 20.0;
    g.setColor(new PDFColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 30.0 + r.y * FS, r.w * FS, r.h * FS);
    g.fillPath();
    g.setColor(new PDFColor(0.3, 0.3, 0.3));
    g.drawString(font2, FS, s, 50.0, 30.0);

    g.setColor(new PDFColor(1.0, 0.0, 0.0));
    g.drawString(font2, 20.0, "Hé (Olà)", 50.0, 10.0);
    g.drawLine(30.0, 30.0, 200.0, 200.0);
    g.strokePath();
    g.setColor(new PDFColor(1.0, 0.0, 0.0));
    g.drawRect(300.0, 150.0, 50.0, 50.0);
    g.fillPath();
    g.setColor(new PDFColor(0.0, 0.5, 0.0));
    var image = new PDFImage(pdf, img);
    for (var i = 10.0; i < 90.0; i += 5.0) {
      g.saveContext();
      var tm = new Matrix4.identity();
      tm.rotateZ(i * pi / 360.0);
      tm.translate(300.0, -100.0);
      g.setTransform(tm);
      g.drawString(font1, 12.0, "Hello $i", 20.0, 100.0);
      g.drawImage(image, 100.0, 100.0, 80.0);
      g.restoreContext();
    }

    var file = new File('file.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
