import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void printText(PdfGraphics g, String text, PdfFont font, double top) {
  text = text + font.fontName;
  var r = font.stringBounds(text);
  const FS = 20.0;
  g.setColor(PdfColor(0.9, 0.9, 0.9));
  g.drawRect(50.0 + r.x * FS, g.page.pageFormat.height - top + r.y * FS,
      r.w * FS, r.h * FS);
  g.fillPath();
  g.setColor(PdfColor(0.3, 0.3, 0.3));
  g.drawString(font, FS, text, 50.0, g.page.pageFormat.height - top);
}

void main() {
  test('Pdf', () {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 430.0));

    var g = page.getGraphics();
    var top = 0;
    const s = "Hello ";

    printText(g, s, PdfFont.courier(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierOblique(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.helvetica(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaOblique(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.times(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesItalic(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesBoldItalic(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.symbol(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.zapfDingbats(pdf), 20.0 + 30.0 * top++);

    var file = File('file3.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
