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

class PdfAnnot extends PdfObject {
  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  /// The size of the annotation
  final PdfRect srcRect;

  /// The text of a text annotation
  final String s;

  /// Link to the Destination page
  final PdfObject dest;

  /// If destRect is null then this is the region of the destination page shown.
  /// Otherwise they are ignored.
  final PdfRect destRect;

  /// the border for this annotation
  PdfBorder border;

  PdfAnnot(PdfPage pdfPage,
      {String type,
      this.s,
      this.srcRect,
      this.subtype,
      this.dest,
      this.destRect})
      : super(pdfPage.pdfDocument, type) {
    pdfPage.annotations.add(this);
  }

  /// This is used to create an annotation.
  /// @param s Subtype for this annotation
  /// @param rect coordinates
  factory PdfAnnot.annotation(PdfPage pdfPage, String s, PdfRect rect) =>
      PdfAnnot(pdfPage, type: "/Annot", s: s, srcRect: rect);

  /// Creates a text annotation
  /// @param rect coordinates
  /// @param s Text for this annotation
  factory PdfAnnot.text(PdfPage pdfPage, PdfRect rect, String s) =>
      PdfAnnot(pdfPage, type: "/Text", srcRect: rect, s: s);

  /// Creates a link annotation
  /// @param srcRect coordinates
  /// @param dest Destination for this link. The page will fit the display.
  /// @param destRect Rectangle describing what part of the page to be displayed
  /// (must be in User Coordinates)
  factory PdfAnnot.link(PdfPage pdfPage, PdfRect srcRect, PdfObject dest,
          [PdfRect destRect]) =>
      PdfAnnot(pdfPage,
          type: "/Link", srcRect: srcRect, dest: dest, destRect: destRect);

  /// Sets the border for the annotation. By default, no border is defined.
  ///
  /// If the style is dashed, then this method uses Pdf's default dash
  /// scheme {3}
  ///
  /// Important: the annotation must have been added to the document before
  /// this is used. If the annotation was created using the methods in
  /// [PdfPage], then the annotation is already in the document.
  ///
  /// @param style Border style solid, dashed, beveled, inset or underlined.
  /// @param width Width of the border
  /// @param dash Array of lengths, used for drawing the dashes. If this
  /// is null, then the default of {3} is used.
  void setBorder(double width,
      {PdfBorderStyle style = PdfBorderStyle.solid, List<double> dash}) {
    border = PdfBorder(pdfDocument, width, style: style, dash: dash);
  }

  /// Output the annotation
  ///
  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    params["/Subtype"] = PdfStream.string(subtype);
    params["/Rect"] = PdfStream.string(
        "[${srcRect.l} ${srcRect.b} ${srcRect.r} ${srcRect.t}]");

    // handle the border
    if (border == null) {
      params["/Border"] = PdfStream.string("[0 0 0]");
    } else {
      params["/BS"] = border.ref();
    }

    // Now the annotation subtypes
    if (subtype == "/Text") {
      params["/Contents"] = PdfStream.string(s);
    } else if (subtype == "/Link") {
      var dests = List<PdfStream>();
      dests.add(dest.ref());
      if (destRect == null)
        dests.add(PdfStream.string("/Fit"));
      else {
        dests.add(PdfStream.string(
            "/FitR ${destRect.l} ${destRect.b} ${destRect.r} ${destRect.t}"));
      }
      params["/Dest"] = PdfStream.array(dests);
    }
  }
}
