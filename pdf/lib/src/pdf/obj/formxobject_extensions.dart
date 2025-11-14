import 'dart:convert';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../../pdf.dart';
import '../../../widgets.dart' as pw;
import '../../priv.dart';
import '../../svg/painter.dart';
import '../../svg/parser.dart';
import 'formxobject.dart';

/// A [PdfFormXObject] that renders an SVG graphic into the form's content stream.
///
/// This subclass allows embedding SVG content (provided as [Uint8List] bytes) as
/// vector graphics within a PDF Form XObject. The SVG is parsed using [SvgParser]
/// and painted onto the form's graphics context, with an inverted Y-axis transform
/// applied to match PDF's coordinate system (origin at bottom-left). Fonts or
/// other resources from the SVG are not automatically collected—ensure they are
/// handled via the owning [PdfDocument] if needed.
class SvgPdfFormXObject extends PdfFormXObject {
  @override
  String get name => '/X$objser';
  SvgPdfFormXObject(
    super.doc,
    Uint8List svgBytes,
    double width,
    double height,
  ) {
    params['/BBox'] = PdfArray.fromNum([0, 0, width, height]);

    final rect = PdfRect(0, 0, width, height);
    final td = pw.Document().document;
    final tp = PdfPage(td, pageFormat: PdfPageFormat.a4);
    final g = PdfGraphics(tp, buf);

    final document = XmlDocument.parse(utf8.decode(svgBytes));
    final svgp = SvgParser(xml: document);
    final p = SvgPainter(svgp, g, td, rect);

    g.saveContext();
    // Create the transform: scale y by -1 (flip), then translate to compensate.
    final transform = Matrix4.identity()
      ..scaleByVector3(Vector3(1.0, -1.0, 1.0))
      ..translateByVector3(Vector3(0.0, -rect.height, 0.0));
    g.setTransform(transform);
    p.paint();
    g.restoreContext();
    //_printContent(buf);
  }
}

/// A [PdfFormXObject] that renders a  PDF widget into the form's content stream.
///
/// This subclass allows embedding arbitrary [pw.Widget]s (from the `pdf/widgets` package)
/// as vector graphics within a PDF Form XObject. The widget is laid out and painted
/// using tight box constraints matching the provided dimensions. Fonts used by the
/// widget are automatically collected and added to the form's font set for reference
/// resolution in the final PDF.
class WidgetPdfFormXObject extends PdfFormXObject {
  WidgetPdfFormXObject(
    PdfDocument doc,
    pw.Widget widget,
    double width,
    double height, {
    pw.ThemeData? themeData,
  }) : super(doc) {
    params['/BBox'] = PdfArray.fromNum([0, 0, width, height]);
    final td = pw.Document(theme: themeData ?? pw.ThemeData()).document;
    final tp = PdfPage(td, pageFormat: PdfPageFormat.a4);
    final g = PdfGraphics(tp, buf);
    final themedWidget = pw.Theme(
      data: themeData ?? pw.ThemeData(),
      child: widget,
    );
    final context = pw.Context(document: doc, page: tp, canvas: g);
    // Create layout constraints and box
    themedWidget.layout(
      context,
      pw.BoxConstraints.tightFor(width: width, height: height),
    );
    themedWidget.paint(context);
    fonts.addAll(tp.fonts);
  }
  @override
  String get name => '/X$objser';
}

