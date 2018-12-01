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

class PdfCatalog extends PdfObject {
  /// The pages of the document
  final PdfPageList pdfPageList;

  /// The outlines of the document
  PdfOutline outlines;

  /// The initial page mode
  final PdfPageMode pageMode;

  /// This constructs a Pdf Catalog object
  ///
  /// @param pdfPageList The [PdfPageList] object that's the root of the documents page tree
  /// @param pagemode How the document should appear when opened.
  /// Allowed values are usenone, useoutlines, usethumbs or fullscreen.
  PdfCatalog(PdfDocument pdfDocument, this.pdfPageList, this.pageMode)
      : super(pdfDocument, "/Catalog");

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    params["/Pages"] = pdfPageList.ref();

    // the Outlines object
    if (outlines != null && outlines.outlines.length > 0) {
      params["/Outlines"] = outlines.ref();
    }

    // the /PageMode setting
    params["/PageMode"] =
        PdfStream.string(PdfDocument._PdfPageModes[pageMode.index]);
  }
}
