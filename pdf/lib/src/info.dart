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

class PdfInfo extends PdfObject {
  String author;
  String creator;
  String title;
  String subject;
  String keywords;

  /// @param title Title of this document
  PdfInfo(PdfDocument pdfDocument,
      {this.title, this.author, this.creator, this.subject, this.keywords})
      : super(pdfDocument, null) {
    params["/Producer"] = PdfStream.text("dpdf - David PHAM-VAN");
  }

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    if (author != null) params["/Author"] = PdfStream.textUtf16(author, true);
    if (creator != null)
      params["/Creator"] = PdfStream.textUtf16(creator, true);
    if (title != null) params["/Title"] = PdfStream.textUtf16(title, true);
    if (subject != null)
      params["/Subject"] = PdfStream.textUtf16(subject, true);
    if (keywords != null)
      params["/Keywords"] = PdfStream.textUtf16(keywords, true);
  }
}
