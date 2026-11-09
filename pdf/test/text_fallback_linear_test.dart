import 'dart:convert';

import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  test('supported text surrounding unsupported runes is not dropped', () async {
    final document = pw.Document(compress: false);
    document.addPage(
      pw.Page(
        build: (context) => pw.RichText(
          text: pw.TextSpan(
            text: 'ABC😀DEF😃GHI',
            style: pw.TextStyle(font: pw.Font.helvetica()),
          ),
        ),
      ),
    );

    final data = latin1.decode(await document.save());
    expect(data, contains('(ABC)'));
    expect(data, contains('(DEF)'));
    expect(data, contains('(GHI)'));
  });

  test('repeated fallback characters preserve all adjacent text', () async {
    final document = pw.Document(compress: false);
    final value = List.filled(120, 'x😀').join() + 'END';
    document.addPage(
      pw.Page(
        build: (context) => pw.RichText(
          text: pw.TextSpan(
            text: value,
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 3),
          ),
          softWrap: false,
        ),
      ),
    );
    final data = latin1.decode(await document.save());
    expect(RegExp(r'\(x\)').allMatches(data).length, 120);
    expect(data, contains('(END)'));
  });
}
