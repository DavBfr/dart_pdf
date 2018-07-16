/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PDFAnnot extends PDFObject {
  /// Solid border. The border is drawn as a solid line.
  static const SOLID = 0;

  /// The border is drawn with a dashed line.
  static const DASHED = 1;

  /// The border is drawn in a beveled style (faux three-dimensional) such
  /// that it looks as if it is pushed out of the page (opposite of INSET)
  static const BEVELED = 2;

  /// The border is drawn in an inset style (faux three-dimensional) such
  /// that it looks as if it is inset into the page (opposite of BEVELED)
  static const INSET = 3;

  /// The border is drawn as a line on the bottom of the annotation rectangle
  static const UNDERLINED = 4;

  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  /// The size of the annotation
  final double l, b, r, t;

  /// The text of a text annotation
  final String s;

  /// flag used to indicate that the destination should fit the screen
  static const FULL_PAGE = -9999.0;

  /// Link to the Destination page
  PDFObject dest;

  /// If fl!=FULL_PAGE then this is the region of the destination page shown.
  /// Otherwise they are ignored.
  final double fl, fb, fr, ft;

  /// the border for this annotation
  PDFBorder border;

  PDFAnnot(PDFPage pdfPage,
      {String type,
      this.s,
      this.l,
      this.b,
      this.r,
      this.t,
      this.subtype,
      this.dest,
      this.fl,
      this.fb,
      this.fr,
      this.ft})
      : super(pdfPage.pdfDocument, type) {
    pdfPage.annotations.add(this);
  }

  /// This is used to create an annotation.
  /// @param s Subtype for this annotation
  /// @param l Left coordinate
  /// @param b Bottom coordinate
  /// @param r Right coordinate
  /// @param t Top coordinate
  factory PDFAnnot.annotation(
          PDFPage pdfPage, String s, double l, double b, double r, double t) =>
      new PDFAnnot(pdfPage, type: "/Annot", s: s, l: l, b: b, r: r, t: t);

  /// Creates a text annotation
  /// @param l Left coordinate
  /// @param b Bottom coordinate
  /// @param r Right coordinate
  /// @param t Top coordinate
  /// @param s Text for this annotation
  factory PDFAnnot.text(PDFPage pdfPage, double l, double b, double r, double t, String s) =>
      new PDFAnnot(pdfPage, type: "/Text", l: l, b: b, r: r, t: t, s: s);

  /// Creates a link annotation
  /// @param l Left coordinate
  /// @param b Bottom coordinate
  /// @param r Right coordinate
  /// @param t Top coordinate
  /// @param dest Destination for this link. The page will fit the display.
  /// @param fl Left coordinate
  /// @param fb Bottom coordinate
  /// @param fr Right coordinate
  /// @param ft Top coordinate
  /// <br><br>Rectangle describing what part of the page to be displayed
  /// (must be in User Coordinates)
  factory PDFAnnot.link(
          PDFPage pdfPage, double l, double b, double r, double t, PDFObject dest,
          [double fl = FULL_PAGE,
          double fb = FULL_PAGE,
          double fr = FULL_PAGE,
          double ft = FULL_PAGE]) =>
      new PDFAnnot(pdfPage,
          type: "/Link", l: l, b: b, r: r, t: t, dest: dest, fl: fl, fb: fb, fr: fr, ft: ft);

  /// Sets the border for the annotation. By default, no border is defined.
  ///
  /// <p>If the style is DASHED, then this method uses PDF's default dash
  /// scheme {3}
  ///
  /// <p>Important: the annotation must have been added to the document before
  /// this is used. If the annotation was created using the methods in
  /// PDFPage, then the annotation is already in the document.
  ///
  /// @param style Border style SOLID, DASHED, BEVELED, INSET or UNDERLINED.
  /// @param width Width of the border
  /// @param dash Array of lengths, used for drawing the dashes. If this
  /// is null, then the default of {3} is used.
  void setBorder(double width, {int style = 0, List<double> dash}) {
    border = new PDFBorder(pdfDocument, width, style: style, dash: dash);
  }

  /// Output the annotation
  ///
  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    params["/Subtype"] = PDFStream.string(subtype);
    params["/Rect"] = PDFStream.string("[$l $b $r $t]");

    // handle the border
    if (border == null) {
      params["/Border"] = PDFStream.string("[0 0 0]");
    } else {
      params["/BS"] = border.ref();
    }

    // Now the annotation subtypes
    if (subtype == "/Text") {
      params["/Contents"] = PDFStream.string(s);
    } else if (subtype == "/Link") {
      var dests = new List<PDFStream>();
      dests.add(dest.ref());
      if (fl == FULL_PAGE)
        dests.add(PDFStream.string("/Fit"));
      else {
        dests.add(PDFStream.string("/FitR $fl $fb $fr $ft"));
      }
      params["/Dest"] = PDFStream.array(dests);
    }
  }
}
