import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:printing/printing.dart';

mixin {{name.pascalCase()}}Theme {
  PdfColor get baseColor => PdfColors.blue;

  List<PdfColor> get chartColors => [
        PdfColors.blue300,
        PdfColors.green300,
        PdfColors.amber300,
        PdfColors.pink300,
        PdfColors.cyan300,
        PdfColors.purple300,
        PdfColors.lime300,
      ];

  Future<PageTheme> buildPageTheme({
    PdfPageFormat? pageFormat,
  }) async {
    final theme = ThemeData.withFont(
      base: await PdfGoogleFonts.openSansRegular(),
      bold: await PdfGoogleFonts.openSansBold(),
      italic: await PdfGoogleFonts.openSansItalic(),
      boldItalic: await PdfGoogleFonts.openSansBoldItalic(),
      icons: await PdfGoogleFonts.materialIcons(),
    );

    return PageTheme(
      pageFormat: pageFormat,
      theme: theme,
    );
  }
}
