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
  SvgPdfFormXObject(
    super.doc,
    Uint8List svgBytes,
    double width,
    double height,
  ) {
    params['/BBox'] = PdfArray.fromNum([0, 0, width, height]);

    final rect = PdfRect(0, 0, width, height);

    // Painted into this form, against the document that owns it: everything
    // PdfGraphics and SvgPainter register - fonts, shaders, patterns - then
    // belongs to this form's /Resources and is serialised with the file. It used
    // to be a page of a second, discarded document, so the form's stream named
    // objects nobody ever wrote.
    final g = PdfGraphics(this, buf);

    final document = XmlDocument.parse(utf8.decode(svgBytes));
    final svgp = SvgParser(xml: document);
    final p = SvgPainter(svgp, g, pdfDocument, rect);

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
    PdfPage? page,
  }) : super(doc) {
    params['/BBox'] = PdfArray.fromNum([0, 0, width, height]);

    // Painted into this form, against the document that owns it, so its
    // resources are its own and are written with the file.
    final g = PdfGraphics(this, buf);
    final themedWidget = pw.Theme(
      data: themeData ?? pw.ThemeData(),
      child: widget,
    );

    // A widget that reads Context.page - a page number, a page label - needs a
    // real one; there is no page of our own to offer it.
    final context = pw.Context(document: doc, page: page, canvas: g);
    // Create layout constraints and box
    themedWidget.layout(
      context,
      pw.BoxConstraints.tightFor(width: width, height: height),
    );
    themedWidget.paint(context);
  }
}
