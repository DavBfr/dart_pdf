/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of pdf;

@deprecated
class PDFAnnot extends PdfAnnot {
  PDFAnnot(PdfPage pdfPage,
      {String type,
      String s,
      double l,
      double b,
      double r,
      double t,
      String subtype,
      PdfObject dest,
      double fl,
      double fb,
      double fr,
      double ft})
      : super._create(pdfPage,
            type: type,
            content: s,
            srcRect: PdfRect.fromLTRB(l, t, r, b),
            subtype: subtype,
            dest: dest,
            destRect: PdfRect.fromLTRB(fl, ft, fr, fb));

  factory PDFAnnot.annotation(
          PdfPage pdfPage, String s, double l, double b, double r, double t) =>
      PDFAnnot(pdfPage, type: '/Annot', s: s, l: l, b: b, r: r, t: t);

  factory PDFAnnot.text(
          PdfPage pdfPage, double l, double b, double r, double t, String s) =>
      PDFAnnot(pdfPage, type: '/Text', l: l, b: b, r: r, t: t, s: s);

  factory PDFAnnot.link(PdfPage pdfPage, double l, double b, double r, double t,
          PdfObject dest,
          [double fl = FULL_PAGE,
          double fb = FULL_PAGE,
          double fr = FULL_PAGE,
          double ft = FULL_PAGE]) =>
      PDFAnnot(pdfPage,
          type: '/Link',
          l: l,
          b: b,
          r: r,
          t: t,
          dest: dest,
          fl: fl,
          fb: fb,
          fr: fr,
          ft: ft);

  static const PdfBorderStyle SOLID = PdfBorderStyle.solid;
  static const PdfBorderStyle DASHED = PdfBorderStyle.dashed;
  static const PdfBorderStyle BEVELED = PdfBorderStyle.beveled;
  static const PdfBorderStyle INSET = PdfBorderStyle.inset;
  static const PdfBorderStyle UNDERLINED = PdfBorderStyle.underlined;
  static const double FULL_PAGE = -9999;
}

@deprecated
class PDFArrayObject extends PdfArrayObject {
  PDFArrayObject(PdfDocument pdfDocument, List<String> values)
      : super(pdfDocument, values);
}

@deprecated
class PDFBorder extends PdfBorder {
  PDFBorder(PdfDocument pdfDocument, double width,
      {int style, List<double> dash})
      : super(pdfDocument, width,
            style: PdfBorderStyle.values[style], dash: dash);
}

@deprecated
class PDFCatalog extends PdfCatalog {
  PDFCatalog(PdfDocument pdfDocument, PdfPageList pdfPageList,
      PdfPageMode pageMode, PdfNames names)
      : super(pdfDocument, pdfPageList, pageMode, names);
}

@deprecated
class PDFDocument extends PdfDocument {
  PDFDocument(
      {PdfPageMode pageMode = PdfPageMode.none, DeflateCallback deflate})
      : super(pageMode: pageMode, deflate: deflate);
}

@deprecated
class PDFColor extends PdfColor {
  PDFColor(double r, double g, double b, [double a = 1.0]) : super(r, g, b, a);

  factory PDFColor.fromInt(int color) {
    final PdfColor c = PdfColor.fromInt(color);
    return PDFColor(c.r, c.g, c.b, c.a);
  }

  factory PDFColor.fromHex(String color) {
    final PdfColor c = PdfColor.fromHex(color);
    return PDFColor(c.r, c.g, c.b, c.a);
  }
}

@deprecated
class PDFFontDescriptor extends PdfFontDescriptor {
  PDFFontDescriptor(PdfTtfFont ttfFont, PdfObjectStream file)
      : super(ttfFont, file);
}

@deprecated
class PDFFont extends PdfFont {
  factory PDFFont(PdfDocument pdfDocument, {String subtype, String baseFont}) {
    subtype ??= baseFont;
    return PdfFont.helvetica(pdfDocument);
  }

  @override
  PdfFontMetrics glyphMetrics(int charCode) {
    return PdfFontMetrics.zero;
  }
}

@deprecated
class PDFFormXObject extends PdfFormXObject {
  PDFFormXObject(PdfDocument pdfDocument) : super(pdfDocument);
}

@deprecated
class PDFGraphics extends PdfGraphics {
  PDFGraphics(PdfPage page, PdfStream buf) : super(page, buf);
}

@deprecated
class PDFImage extends PdfImage {
  PDFImage(PdfDocument pdfDocument,
      {@required Uint8List image,
      @required int width,
      @required int height,
      bool alpha = true,
      bool alphaChannel = false})
      : super(pdfDocument,
            image: image,
            width: width,
            height: height,
            alpha: alpha,
            alphaChannel: alphaChannel);
}

@deprecated
class PDFInfo extends PdfInfo {
  PDFInfo(PdfDocument pdfDocument,
      {String title,
      String author,
      String creator,
      String subject,
      String keywords})
      : super(pdfDocument,
            title: title,
            author: author,
            creator: creator,
            subject: subject,
            keywords: keywords);
}

@deprecated
class PDFObjectStream extends PdfObjectStream {
  PDFObjectStream(PdfDocument pdfDocument, {String type, bool isBinary = false})
      : super(pdfDocument, type: type, isBinary: isBinary);
}

@deprecated
class PDFObject extends PdfObject {
  PDFObject(PdfDocument pdfDocument, [String type]) : super(pdfDocument, type);
}

@deprecated
class PDFOutline extends PdfOutline {
  PDFOutline(PdfDocument pdfDocument,
      {String title, PdfPage dest, double l, double b, double r, double t})
      : super(pdfDocument,
            title: title, dest: dest, rect: PdfRect.fromLTRB(l, t, r, b));

  @deprecated
  static const PdfOutlineMode FITPAGE = PdfOutlineMode.fitpage;

  @deprecated
  static const PdfOutlineMode FITRECT = PdfOutlineMode.fitrect;
}

@deprecated
class PDFOutput extends PdfOutput {
  PDFOutput(PdfStream os) : super(os);
}

@deprecated
class PDFPageFormat extends PdfPageFormat {
  const PDFPageFormat(double width, double height) : super(width, height);

  static const PdfPageFormat a4 = PdfPageFormat.a4;
  static const PdfPageFormat a3 = PdfPageFormat.a3;
  static const PdfPageFormat a5 = PdfPageFormat.a5;
  static const PdfPageFormat letter = PdfPageFormat.letter;
  static const PdfPageFormat legal = PdfPageFormat.legal;
  static const double point = PdfPageFormat.point;
  static const double inch = PdfPageFormat.inch;
  static const double cm = PdfPageFormat.cm;
  static const double mm = PdfPageFormat.mm;
  static const PdfPageFormat A4 = a4;
  static const PdfPageFormat A3 = a3;
  static const PdfPageFormat A5 = a5;
  static const PdfPageFormat LETTER = letter;
  static const PdfPageFormat LEGAL = legal;
  static const double PT = point;
  static const double IN = inch;
  static const double CM = cm;
  static const double MM = mm;
}

@deprecated
class PDFPageList extends PdfPageList {
  PDFPageList(PdfDocument pdfDocument) : super(pdfDocument);
}

@deprecated
class PDFPage extends PdfPage {
  PDFPage(PdfDocument pdfDocument, {PdfPageFormat pageFormat})
      : super(pdfDocument, pageFormat: pageFormat);

  /// Returns the page's PageFormat.
  /// @return PageFormat describing the page size in device units (72dpi)
  /// use pageFormat
  @deprecated
  PdfPageFormat getPageFormat() {
    return pageFormat;
  }

  /// Gets the dimensions of the page.
  /// @return a Dimension object containing the width and height of the page.
  /// use pageFormat.dimension
  @deprecated
  PdfPoint getDimension() => PdfPoint(pageFormat.width, pageFormat.height);

  /// This method adds a text note to the document.
  /// @param note Text of the note
  /// @param x Coordinate of note
  /// @param y Coordinate of note
  /// @param w Width of the note
  /// @param h Height of the note
  /// @return Returns the annotation, so other settings can be changed.
  @deprecated
  PdfAnnot addNote(String note, double x, double y, double w, double h) {
    final PdfPoint xy1 = cxy(x, y + h);
    final PdfPoint xy2 = cxy(x + w, y);
    final PdfAnnot ob = PdfAnnot.text(this,
        rect: PdfRect.fromLTRB(xy1.x, xy1.y, xy2.x, xy2.y), content: note);
    return ob;
  }

  /// Adds a hyperlink to the document.
  /// @param x Coordinate of active area
  /// @param y Coordinate of active area
  /// @param w Width of the active area
  /// @param h Height of the active area
  /// @param dest Page that will be displayed when the link is activated. When
  /// displayed, the zoom factor will be changed to fit the display.
  /// @param vx Coordinate of view area
  /// @param vy Coordinate of view area
  /// @param vw Width of the view area
  /// @param vh Height of the view area
  /// @return Returns the annotation, so other settings can be changed.
  @deprecated
  PdfAnnot addLink(double x, double y, double w, double h, PdfObject dest,
      [double vx = PDFAnnot.FULL_PAGE,
      double vy = PDFAnnot.FULL_PAGE,
      double vw = PDFAnnot.FULL_PAGE,
      double vh = PDFAnnot.FULL_PAGE]) {
    final PdfPoint xy1 = cxy(x, y + h);
    final PdfPoint xy2 = cxy(x + w, y);
    final PdfPoint xy3 = cxy(vx, vy + vh);
    final PdfPoint xy4 = cxy(vx + vw, vy);
    final PdfAnnot ob = PdfAnnot.link(this,
        srcRect: PdfRect.fromLTRB(xy1.x, xy1.y, xy2.x, xy2.y),
        dest: dest,
        destRect: PdfRect.fromLTRB(xy3.x, xy3.y, xy4.x, xy4.y));
    return ob;
  }

  /// This method attaches an outline to the current page being generated. When
  /// selected, the outline displays the top of the page.
  /// @param title Outline title to attach
  /// @param x Left coordinate of region
  /// @param y Bottom coordinate of region
  /// @param w Width of region
  /// @param h Height coordinate of region
  /// @return [PdfOutline] object created, for addSubOutline if required.
  @deprecated
  PdfOutline addOutline(String title,
      {double x, double y, double w, double h}) {
    final PdfPoint xy1 = cxy(x, y + h);
    final PdfPoint xy2 = cxy(x + w, y);
    final PdfOutline outline = PdfOutline(pdfDocument,
        title: title,
        dest: this,
        rect: PdfRect.fromLTRB(xy1.x, xy2.y, xy2.x, xy1.y));
    pdfDocument.outline.outlines.add(outline);
    return outline;
  }

  /// This utility method converts the y coordinate to User space
  /// within the page.
  /// @param x Coordinate in User space
  /// @param y Coordinate in User space
  /// @return y Coordinate in User space
  @deprecated
  double cy(double x, double y) => cxy(x, y).y;

  /// This utility method converts the x coordinate to User space
  /// within the page.
  /// @param x Coordinate in User space
  /// @param y Coordinate in User space
  /// @return x Coordinate in User space
  @deprecated
  double cx(double x, double y) => cxy(x, y).x;

  /// This utility method converts the coordinates to User space
  /// within the page.
  /// @param x Coordinate in User space
  /// @param y Coordinate in User space
  /// @return array containing the x & y Coordinate in User space
  @deprecated
  PdfPoint cxy(double x, double y) => PdfPoint(x, pageFormat.height - y);
}

@deprecated
class PDFPoint extends PdfPoint {
  const PDFPoint(double w, double h) : super(w, h);
}

@deprecated
class PDFRect extends PdfRect {
  const PDFRect(double x, double y, double w, double h) : super(x, y, w, h);
}

@deprecated
class PDFStream extends PdfStream {}

@deprecated
class TTFParser extends TtfParser {
  TTFParser(ByteData bytes) : super(bytes);
}

@deprecated
class PDFTTFFont extends PdfTtfFont {
  PDFTTFFont(PdfDocument pdfDocument, ByteData bytes)
      : super(pdfDocument, bytes);
}

@deprecated
class PDFXObject extends PdfXObject {
  PDFXObject(PdfDocument pdfDocument, String subtype)
      : super(pdfDocument, subtype);
}

@deprecated
enum PDFPageMode { NONE, OUTLINES, THUMBS, FULLSCREEN }

@deprecated
enum PDFLineCap { JOIN_MITER, JOIN_ROUND, JOIN_BEVEL }

@deprecated
class PDFXref extends PdfXref {
  PDFXref(int id, int offset) : super(id, offset);
}
