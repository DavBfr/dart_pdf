import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart' show PdfStream;
import 'package:test/test.dart';

void main() {
  test('TTF text reuses Unicode CIDs across repeated runs', () {
    final bytes = File('open-sans.ttf').readAsBytesSync();
    final font = PdfTtfFont(PdfDocument(), bytes.buffer.asByteData());
    expect(font.font.unicode, isTrue);

    final first = PdfStream();
    font.putText(first, 'אבבא');
    expect(latin1.decode(first.output()), '<0001000200020001>');
    expect(font.unicodeCMap.cmap, [0, 0x05d0, 0x05d1]);

    final second = PdfStream();
    font.putText(second, 'בא');
    expect(latin1.decode(second.output()), '<00020001>');
    expect(font.unicodeCMap.cmap.length, 3);

    // Direct append to the public cmap should remain compatible.
    font.unicodeCMap.cmap.add(0x05d2);
    final third = PdfStream();
    font.putText(third, 'ג');
    expect(latin1.decode(third.output()), '<0003>');
    expect(font.unicodeCMap.cmap.length, 4);
  });
}
