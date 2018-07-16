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

class PDFPage extends PDFObject {
  /// This is this page format, ie the size of the page, margins, and rotation
  PDFPageFormat pageFormat;

  /// This holds the contents of the page.
  List<PDFObjectStream> contents = [];

  /// Object ID that contains a thumbnail sketch of the page.
  /// -1 indicates no thumbnail.
  PDFObject thumbnail;

  /// This holds any Annotations contained within this page.
  List<PDFAnnot> annotations = [];

  /// The fonts associated with this page
  final fonts = new Map<String, PDFFont>();

  /// The xobjects or other images in the pdf
  final xObjects = new Map<String, PDFXObject>();

  /// This constructs a Page object, which will hold any contents for this
  /// page.
  ///
  /// <p>Once created, it is added to the document via the PDF.add() method.
  ///
  /// @param orientation Orientation: 0, 90 or 270
  /// @see PageFormat#PORTRAIT
  /// @see PageFormat#LANDSCAPE
  /// @see PageFormat#REVERSE_LANDSCAPE
  /// @param pageFormat PageFormat describing the page size
  PDFPage(PDFDocument pdfDocument, {int orientation, this.pageFormat})
      : super(pdfDocument, "/Page") {
    pdfDocument.pdfPageList.pages.add(this);
    if (pageFormat == null) pageFormat = new PDFPageFormat();
    setOrientation(orientation);
  }

  /// This returns a PDFGraphics object, which can then be used to render
  /// on to this page. If a previous PDFGraphics object was used, this object
  /// is appended to the page, and will be drawn over the top of any previous
  /// objects.
  ///
  /// @return a new PDFGraphics object to be used to draw this page.
  PDFGraphics getGraphics() {
    var stream = new PDFObjectStream(pdfDocument);
    var g = new PDFGraphics(this, stream.buf);
    contents.add(stream);
    return g;
  }

  /// Returns the page's PageFormat.
  /// @return PageFormat describing the page size in device units (72dpi)
  PDFPageFormat getPageFormat() {
    return pageFormat;
  }

  /// Gets the dimensions of the page.
  /// @return a Dimension object containing the width and height of the page.
  PDFPoint getDimension() => new PDFPoint(pageFormat.getWidth(), pageFormat.getHeight());

  /// Sets the page's orientation.
  ///
  /// <p>Normally, this should be done when the page is created, to avoid
  /// problems.
  ///
  /// @param orientation a PageFormat orientation constant:
  /// PageFormat.PORTRAIT, PageFormat.LANDSACPE or PageFromat.REVERSE_LANDSACPE
  void setOrientation(int orientation) {
    pageFormat.setOrientation(orientation);
  }

  /// Returns the pages orientation:
  /// PageFormat.PORTRAIT, PageFormat.LANDSACPE or PageFromat.REVERSE_LANDSACPE
  ///
  /// @see java.awt.print.PageFormat
  /// @return current orientation of the page
  int getOrientation() => pageFormat.getOrientation();

  /// This adds an Annotation to the page.
  ///
  /// <p>As with other objects, the annotation must be added to the pdf
  /// document using PDF.add() before adding to the page.
  ///
  /// @param ob Annotation to add.
  void addAnnotation(PDFObject ob) {
    annotations.add(ob);
  }

  /// This method adds a text note to the document.
  /// @param note Text of the note
  /// @param x Coordinate of note
  /// @param y Coordinate of note
  /// @param w Width of the note
  /// @param h Height of the note
  /// @return Returns the annotation, so other settings can be changed.
  PDFAnnot addNote(String note, double x, y, w, h) {
    var xy1 = cxy(x, y + h);
    var xy2 = cxy(x + w, y);
    PDFAnnot ob = new PDFAnnot.text(this, xy1.w, xy1.h, xy2.w, xy2.h, note);
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
  PDFAnnot addLink(double x, y, w, h, PDFObject dest,
      [double vx = PDFAnnot.FULL_PAGE,
      vy = PDFAnnot.FULL_PAGE,
      vw = PDFAnnot.FULL_PAGE,
      vh = PDFAnnot.FULL_PAGE]) {
    var xy1 = cxy(x, y + h);
    var xy2 = cxy(x + w, y);
    var xy3 = cxy(vx, vy + vh);
    var xy4 = cxy(vx + vw, vy);
    PDFAnnot ob =
        new PDFAnnot.link(this, xy1.w, xy1.h, xy2.w, xy2.h, dest, xy3.w, xy3.h, xy4.w, xy4.h);
    return ob;
  }

  /// This method attaches an outline to the current page being generated. When
  /// selected, the outline displays the top of the page.
  /// @param title Outline title to attach
  /// @param x Left coordinate of region
  /// @param y Bottom coordinate of region
  /// @param w Width of region
  /// @param h Height coordinate of region
  /// @return PDFOutline object created, for addSubOutline if required.
  PDFOutline addOutline(String title, {double x, double y, double w, double h}) {
    PDFPoint xy1 = cxy(x, y + h);
    PDFPoint xy2 = cxy(x + w, y);
    PDFOutline outline = new PDFOutline(pdfDocument,
        title: title, dest: this, l: xy1.w, b: xy1.h, r: xy2.w, t: xy2.h);
    pdfDocument.outline.outlines.add(outline);
    return outline;
  }

  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    // the /Parent pages object
    params["/Parent"] = pdfDocument.pdfPageList.ref();

    // the /MediaBox for the page size
    params["/MediaBox"] = new PDFStream()
      ..putStringArray([0, 0, pageFormat.getWidth(), pageFormat.getHeight()]);

    // Rotation (if not zero)
//        if(rotate!=0) {
//            os.write("/Rotate ");
//            os.write(Integer.toString(rotate).getBytes());
//            os.write("\n");
//        }

    // the /Contents pages object
    if (contents.length > 0) {
      if (contents.length == 1) {
        params["/Contents"] = contents[0].ref();
      } else {
        params["/Contents"] = new PDFStream()..putObjectArray(contents);
      }
    }

    // Now the resources
    /// This holds any resources for this page
    final resources = new Map<String, PDFStream>();

    // fonts
    if (fonts.length > 0) {
      resources["/Font"] = new PDFStream()..putObjectDictionary(fonts);
    }

    // Now the XObjects
    if (xObjects.length > 0) {
      resources["/XObject"] = new PDFStream()..putObjectDictionary(xObjects);
    }

    params["/Resources"] = PDFStream.dictionary(resources);

    // The thumbnail
    if (thumbnail != null) {
      params["/Thumb"] = thumbnail.ref();
    }

    // The /Annots object
    if (annotations.length > 0) {
      params["/Annots"] = new PDFStream()..putObjectArray(annotations);
    }
  }

  /// This utility method converts the y coordinate from Java to User space
  /// within the page.
  /// @param x Coordinate in Java space
  /// @param y Coordinate in Java space
  /// @return y Coordinate in User space
  double cy(double x, double y) => cxy(x, y).h;

  /// This utility method converts the y coordinate from Java to User space
  /// within the page.
  /// @param x Coordinate in Java space
  /// @param y Coordinate in Java space
  /// @return x Coordinate in User space
  double cx(double x, double y) => cxy(x, y).w;

  /// This utility method converts the Java coordinates to User space
  /// within the page.
  /// @param x Coordinate in Java space
  /// @param y Coordinate in Java space
  /// @return array containing the x & y Coordinate in User space
  PDFPoint cxy(double x, double y) => new PDFPoint(x, pageFormat.getHeight() - y);
}
