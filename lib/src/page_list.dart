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

class PDFPageList extends PDFObject {
  /// This holds the pages
  final List<PDFPage> pages = [];

  /// This constructs a PDF Pages object.
  PDFPageList(PDFDocument pdfDocument) : super(pdfDocument, "/Pages");

  /// This returns a specific page. Used by the PDF class.
  /// @param page page number to return
  /// @return PDFPage at that position
  PDFPage getPage(int page) => pages[page];

  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    params["/Kids"] = new PDFStream()..putObjectArray(pages);
    params["/Count"] = PDFStream.intNum(pages.length);
  }
}
