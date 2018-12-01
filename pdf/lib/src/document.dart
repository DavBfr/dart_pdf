/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

enum PdfPageMode {
  /// This page mode indicates that the document
  /// should be opened just with the page visible.  This is the default
  none,

  /// This page mode indicates that the Outlines
  /// should also be displayed when the document is opened.
  outlines,

  /// This page mode indicates that the Thumbnails should be visible when the
  /// document first opens.
  thumbs,

  /// This page mode indicates that when the document is opened, it is displayed
  /// in full-screen-mode. There is no menu bar, window controls nor any other
  /// window present.
  fullscreen
}

typedef List<int> DeflateCallback(List<int> data);

/// This class is the base of the Pdf generator. A [PdfDocument] class is
/// created for a document, and each page, object, annotation,
/// etc is added to the document.
/// Once complete, the document can be written to a Stream, and the Pdf
/// document's internal structures are kept in sync.
class PdfDocument {
  /// This is used to allocate objects a unique serial number in the document.
  int _objser;

  /// This vector contains each indirect object within the document.
  final Set<PdfObject> objects = Set<PdfObject>();

  /// This is the Catalog object, which is required by each Pdf Document
  PdfCatalog catalog;

  /// This is the info object. Although this is an optional object, we
  /// include it.
  PdfInfo info;

  /// This is the Pages object, which is required by each Pdf Document
  PdfPageList pdfPageList;

  /// This is the Outline object, which is optional
  PdfOutline _outline;

  /// This holds a [PdfObject] describing the default border for annotations.
  /// It's only used when the document is being written.
  PdfObject defaultOutlineBorder;

  /// Callback to compress the stream in the pdf file.
  /// Use `deflate: zlib.encode` if using dart:io
  /// No compression by default
  final DeflateCallback deflate;

  /// These map the page modes just defined to the pagemodes setting of Pdf.
  static const _PdfPageModes = const [
    "/UseNone",
    "/UseOutlines",
    "/UseThumbs",
    "/FullScreen"
  ];

  /// This holds the current fonts
  final Set<PdfFont> fonts = Set<PdfFont>();

  /// Creates a new serial number
  int _genSerial() => _objser++;

  /// This creates a Pdf document
  /// @param pagemode an int, determines how the document will present itself to
  /// the viewer when it first opens.
  PdfDocument({PdfPageMode pageMode = PdfPageMode.none, this.deflate}) {
    _objser = 1;

    // Now create some standard objects
    pdfPageList = PdfPageList(this);
    catalog = PdfCatalog(this, pdfPageList, pageMode);
    info = PdfInfo(this);
  }

  /// This returns a specific page. It's used mainly when using a
  /// Serialized template file.
  ///
  /// ?? How does a serialized template file work ???
  ///
  /// @param page page number to return
  /// @return [PdfPage] at that position
  PdfPage page(int page) {
    return pdfPageList.getPage(page);
  }

  /// @return the root outline
  PdfOutline get outline {
    if (_outline == null) {
      _outline = PdfOutline(this);
      catalog.outlines = _outline;
    }
    return _outline;
  }

  /// This writes the document to an OutputStream.
  ///
  /// Note: You can call this as many times as you wish, as long as
  /// the calls are not running at the same time.
  ///
  /// Also, objects can be added or amended between these calls.
  ///
  /// Also, the OutputStream is not closed, but will be flushed on
  /// completion. It is up to the caller to close the stream.
  ///
  /// @param os OutputStream to write the document to
  void _write(PdfStream os) {
    PdfOutput pos = PdfOutput(os);

    // Write each object to the [PdfStream]. We call via the output
    // as that builds the xref table
    for (PdfObject o in objects) {
      pos.write(o);
    }

    // Finally close the output, which writes the xref table.
    pos.close();
  }

  List<int> save() {
    PdfStream os = PdfStream();
    _write(os);
    return os.output();
  }
}
