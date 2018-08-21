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

enum PDFPageMode {
  /// This page mode indicates that the document
  /// should be opened just with the page visible.  This is the default
  NONE,

  /// This page mode indicates that the Outlines
  /// should also be displayed when the document is opened.
  OUTLINES,

  /// This page mode indicates that the Thumbnails should be visible when the
  /// document first opens.
  THUMBS,

  /// This page mode indicates that when the document is opened, it is displayed
  /// in full-screen-mode. There is no menu bar, window controls nor any other
  /// window present.
  FULLSCREEN
}

typedef List<int> DeflateCallback(List<int> data);

/// <p>This class is the base of the PDF generator. A PDFDocument class is
/// created for a document, and each page, object, annotation,
/// etc is added to the document.
/// Once complete, the document can be written to a Stream, and the PDF
/// document's internal structures are kept in sync.
class PDFDocument {
  /// This is used to allocate objects a unique serial number in the document.
  int _objser;

  /// This vector contains each indirect object within the document.
  final Set<PDFObject> objects = new Set<PDFObject>();

  /// This is the Catalog object, which is required by each PDF Document
  PDFCatalog catalog;

  /// This is the info object. Although this is an optional object, we
  /// include it.
  PDFInfo info;

  /// This is the Pages object, which is required by each PDF Document
  PDFPageList pdfPageList;

  /// This is the Outline object, which is optional
  PDFOutline _outline;

  /// This holds a PDFObject describing the default border for annotations.
  /// It's only used when the document is being written.
  PDFObject defaultOutlineBorder;

  /// Callback to compress the stream in the pdf file.
  /// Use `deflate: zlib.encode` if using dart:io
  /// No compression by default
  final DeflateCallback deflate;

  /// <p>
  /// These map the page modes just defined to the pagemodes setting of PDF.
  /// </p>
  static const _PDF_PAGE_MODES = const [
    "/UseNone",
    "/UseOutlines",
    "/UseThumbs",
    "/FullScreen"
  ];

  /// This holds the current fonts
  final Set<PDFFont> fonts = new Set<PDFFont>();

  /// Creates a new serial number
  int _genSerial() => _objser++;

  /// <p>This creates a PDF document</p>
  /// @param pagemode an int, determines how the document will present itself to
  /// the viewer when it first opens.
  PDFDocument({PDFPageMode pageMode = PDFPageMode.NONE, this.deflate}) {
    _objser = 1;

    // Now create some standard objects
    pdfPageList = new PDFPageList(this);
    catalog = new PDFCatalog(this, pdfPageList, pageMode);
    info = new PDFInfo(this);
  }

  /// <p>This returns a specific page. It's used mainly when using a
  /// Serialized template file.</p>
  ///
  /// ?? How does a serialized template file work ???
  ///
  /// @param page page number to return
  /// @return PDFPage at that position
  PDFPage page(int page) {
    return pdfPageList.getPage(page);
  }

  /// @return the root outline
  PDFOutline get outline {
    if (_outline == null) {
      _outline = new PDFOutline(this);
      catalog.outlines = _outline;
    }
    return _outline;
  }

  /// This writes the document to an OutputStream.
  ///
  /// <p><b>Note:</b> You can call this as many times as you wish, as long as
  /// the calls are not running at the same time.
  ///
  /// <p>Also, objects can be added or amended between these calls.
  ///
  /// <p>Also, the OutputStream is not closed, but will be flushed on
  /// completion. It is up to the caller to close the stream.
  ///
  /// @param os OutputStream to write the document to
  void write(PDFStream os) {
    PDFOutput pos = new PDFOutput(os);

    // Write each object to the PDFStream. We call via the output
    // as that builds the xref table
    for (PDFObject o in objects) {
      pos.write(o);
    }

    // Finally close the output, which writes the xref table.
    pos.close();
  }

  List<int> save() {
    PDFStream os = new PDFStream();
    write(os);
    return os.output();
  }
}
