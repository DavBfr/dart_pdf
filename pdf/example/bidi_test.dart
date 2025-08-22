import 'dart:io';

import '../lib/src/shaping/shaping.dart';
import '../lib/src/pdf/obj/ttffont.dart';
import '../lib/src/pdf/document.dart';
import '../lib/src/widgets/widget.dart';
import '../lib/widgets.dart' as pw;

void main() async {
  final primaryFont = pw.Font.ttf(File(
          '../../../secondlayer/napkin-web-client/web/fonts/Roboto/Roboto-Regular.ttf')
      .readAsBytesSync()
      .buffer
      .asByteData());
  final fallbackFonts0 = [
    pw.Font.ttf(File(
            '/Users/arnaudbrejeon/secondLayer/src/secondlayer/napkin-web-client/web/fonts/Geeza_Pro/GeezaPro-01.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
  ];
  final fallbackFonts1 = [
    pw.Font.ttf(File(
            '/Users/arnaudbrejeon/secondLayer/src/secondlayer/napkin-web-client/web/fonts/Lateef/Lateef-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
  ];

  final context = Context(document: PdfDocument());

  print(str.runes.toList());

  final results = Shaping().shape(
      str,
      primaryFont.getFont(context) as PdfTtfFont,
      fallbackFonts0
          .map((f) => f.getFont(context))
          .whereType<PdfTtfFont>()
          .toList());
  print(results);

  print('---------------');

  final results1 = Shaping().shape(
      str,
      primaryFont.getFont(context) as PdfTtfFont,
      fallbackFonts1
          .map((f) => f.getFont(context))
          .whereType<PdfTtfFont>()
          .toList());
  print(results1);

  Shaping().dispose();
}

const str = 'مرحبا بالعالم AAA';
