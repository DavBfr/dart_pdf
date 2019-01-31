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

class PdfAnnot extends PdfObject {
  /// The subtype of the outline, ie text, note, etc
  final String subtype;

  /// The size of the annotation
  final PdfRect srcRect;

  /// The text of a text annotation
  final String content;

  /// Link to the Destination page
  final PdfObject dest;

  /// If destRect is null then this is the region of the destination page shown.
  /// Otherwise they are ignored.
  final PdfRect destRect;

  /// the border for this annotation
  final PdfBorder border;

  PdfAnnot._create(PdfPage pdfPage,
      {String type,
      this.content,
      this.srcRect,
      @required this.subtype,
      this.dest,
      this.destRect,
      this.border})
      : super(pdfPage.pdfDocument, type ?? '/Annot') {
    pdfPage.annotations.add(this);
  }

  /// Creates a text annotation
  /// @param rect coordinates
  /// @param s Text for this annotation
  factory PdfAnnot.text(PdfPage pdfPage,
          {@required PdfRect rect,
          @required String content,
          PdfBorder border}) =>
      PdfAnnot._create(pdfPage,
          subtype: "/Text", srcRect: rect, content: content, border: border);

  /// Creates a link annotation
  /// @param srcRect coordinates
  /// @param dest Destination for this link. The page will fit the display.
  /// @param destRect Rectangle describing what part of the page to be displayed
  /// (must be in User Coordinates)
  factory PdfAnnot.link(PdfPage pdfPage,
          {@required PdfRect srcRect,
          @required PdfPage dest,
          PdfRect destRect,
          PdfBorder border}) =>
      PdfAnnot._create(pdfPage,
          subtype: "/Link",
          srcRect: srcRect,
          dest: dest,
          destRect: destRect,
          border: border);

  /// Output the annotation
  ///
  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

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
      params["/Contents"] = PdfStream()..putLiteral(content);
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
