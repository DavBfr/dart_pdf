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

class PDFOutline extends PDFObject {
  /// This holds any outlines below us
  List<PDFOutline> outlines = [];

  /// For subentries, this points to it's parent outline
  PDFOutline parent;

  /// This is this outlines Title
  final String title;

  /// The destination page
  PDFPage dest;

  /// The region on the destination page
  final double l, b, r, t;

  /// When jumping to the destination, display the whole page
  static const bool FITPAGE = false;

  /// When jumping to the destination, display the specified region
  static const bool FITRECT = true;

  /// How the destination is handled
  bool destMode = FITPAGE;

  /// Constructs a PDF Outline object. When selected, the specified region
  /// is displayed.
  ///
  /// @param title Title of the outline
  /// @param dest The destination page
  /// @param l left coordinate
  /// @param b bottom coordinate
  /// @param r right coordinate
  /// @param t top coordinate
  PDFOutline(PDFDocument pdfDocument,
      {this.title, this.dest, this.l, this.b, this.r, this.t})
      : super(pdfDocument, "/Outlines");

  /// This method creates an outline, and attaches it to this one.
  /// When the outline is selected, the supplied region is displayed.
  ///
  /// <p>Note: the coordiates are in Java space. They are converted to User
  /// space.
  ///
  /// <p>This allows you to have an outline for say a Chapter,
  /// then under the chapter, one for each section. You are not really
  /// limited on how deep you go, but it's best not to go below say 6 levels,
  /// for the reader's sake.
  ///
  /// @param title Title of the outline
  /// @param dest The destination page
  /// @param x coordinate of region in Java space
  /// @param y coordinate of region in Java space
  /// @param w width of region in Java space
  /// @param h height of region in Java space
  /// @return PDFOutline object created, for creating sub-outlines
  PDFOutline add({String title, PDFPage dest, double x, y, w, h}) {
    var xy1 = dest.cxy(x, y + h);
    var xy2 = dest.cxy(x + w, y);
    PDFOutline outline = new PDFOutline(pdfDocument,
        title: title, dest: dest, l: xy1.w, b: xy1.h, r: xy2.w, t: xy2.h);
    // Tell the outline of ourselves
    outline.parent = this;
    return outline;
  }

  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    // These are for kids only
    if (parent != null) {
      params["/Title"] = PDFStream.string(title);
      var dests = new List<PDFStream>();
      dests.add(dest.ref());

      if (destMode == FITPAGE) {
        dests.add(PDFStream.string("/Fit"));
      } else {
        dests.add(PDFStream.string("/FitR $l $b $r $t"));
      }
      params["/Parent"] = parent.ref();
      params["/Dest"] = PDFStream.array(dests);

      // were a decendent, so by default we are closed. Find out how many
      // entries are below us
      int c = descendants();
      if (c > 0) {
        params["/Count"] = PDFStream.intNum(-c);
      }

      int index = parent.getIndex(this);
      if (index > 0) {
        // Now if were not the first, then we have a /Prev node
        params["/Prev"] = parent.getNode(index - 1).ref();
      }

      if (index < parent.getLast()) {
        // We have a /Next node
        params["/Next"] = parent.getNode(index + 1).ref();
      }
    } else {
      // the number of outlines in this document
      // were the top level node, so all are open by default
      params["/Count"] = PDFStream.intNum(outlines.length);
    }

    // These only valid if we have children
    if (outlines.length > 0) {
      // the number of the first outline in list
      params["/First"] = outlines[0].ref();

      // the number of the last outline in list
      params["/Last"] = outlines[outlines.length - 1].ref();
    }
  }

  /// This is called by children to find their position in this outlines
  /// tree.
  ///
  /// @param outline PDFOutline to search for
  /// @return index within Vector
  int getIndex(PDFOutline outline) => outlines.indexOf(outline);

  /// Returns the last index in this outline
  /// @return last index in outline
  int getLast() => outlines.length - 1;

  /// Returns the outline at a specified position.
  /// @param i index
  /// @return the node at index i
  PDFOutline getNode(int i) => outlines[i];

  /// Returns the total number of descendants below this one.
  /// @return the number of descendants below this one
  int descendants() {
    int c = outlines.length; // initially the number of kids

    // now call each one for their descendants
    for (PDFOutline o in outlines) {
      c += o.descendants();
    }

    return c;
  }
}
