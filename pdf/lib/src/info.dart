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
  static const String _libraryName = "https://github.com/DavBfr/dart_pdf";
  final String author;
  final String creator;
  final String title;
  final String subject;
  final String keywords;
  final String producer;

  /// @param title Title of this document
  PdfInfo(PdfDocument pdfDocument,
      {this.title,
      this.author,
      this.creator,
      this.subject,
      this.keywords,
      this.producer})
      : super(pdfDocument, null) {
    if (author != null) {
      params["/Author"] = PdfStream()..putLiteral(author);
    }
    if (creator != null) {
      params["/Creator"] = PdfStream()..putLiteral(creator);
    }
    if (title != null) {
      params["/Title"] = PdfStream()..putLiteral(title);
    }
    if (subject != null) {
      params["/Subject"] = PdfStream()..putLiteral(subject);
    }
    if (keywords != null) {
      params["/Keywords"] = PdfStream()..putLiteral(keywords);
    }
    if (producer != null) {
      params["/Producer"] = PdfStream()
        ..putLiteral("$producer ($_libraryName)");
    } else {
      params["/Producer"] = PdfStream()..putLiteral(_libraryName);
    }
  }
}
