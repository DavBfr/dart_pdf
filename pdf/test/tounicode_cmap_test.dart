import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/obj/unicode_cmap.dart';
import 'package:test/test.dart';

void main() {
  test('ToUnicode maps large Hebrew character sets in 100-entry blocks', () {
    final map = PdfUnicodeCmap(PdfDocument(), false);
    map.cmap.addAll(List<int>.generate(204, (i) => 0x05d0 + i));
    map.cmap.add(0x1f642); // A supplementary-plane Unicode scalar.
    map.prepare();

    final content = ascii.decode(map.buf.output());
    final entries = RegExp(r'(\d+) beginbfchar')
        .allMatches(content)
        .map((match) => int.parse(match.group(1)!))
        .toList();
    expect(entries, [100, 100, 6]);
    expect(RegExp(r'endbfchar').allMatches(content).length, 3);
    expect(content, contains('<0001> <05D0>'));
    expect(content, contains('<00CD> <D83DDE42>'));
  });

  test('protect masks only the output and preserves the glyph mapping', () {
    final map = PdfUnicodeCmap(PdfDocument(), true);
    map.cmap.addAll([0x05d0, 0x05d1, 0x1f642]);
    final original = List<int>.from(map.cmap);
    map.prepare();

    final content = ascii.decode(map.buf.output());
    expect(map.cmap, original);
    expect(content, contains('<0001> <0020>'));
    expect(content, contains('<0002> <0020>'));
    expect(content, contains('<0003> <0020>'));
  });
}
