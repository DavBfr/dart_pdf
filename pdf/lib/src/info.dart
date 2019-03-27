/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of pdf;

class PdfInfo extends PdfObject {
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
      params['/Author'] = PdfStream()..putLiteral(author);
    }
    if (creator != null) {
      params['/Creator'] = PdfStream()..putLiteral(creator);
    }
    if (title != null) {
      params['/Title'] = PdfStream()..putLiteral(title);
    }
    if (subject != null) {
      params['/Subject'] = PdfStream()..putLiteral(subject);
    }
    if (keywords != null) {
      params['/Keywords'] = PdfStream()..putLiteral(keywords);
    }
    if (producer != null) {
      params['/Producer'] = PdfStream()
        ..putLiteral('$producer ($_libraryName)');
    } else {
      params['/Producer'] = PdfStream()..putLiteral(_libraryName);
    }

    params['/CreationDate'] = PdfStream()..putDate(DateTime.now());
  }

  static const String _libraryName = 'https://github.com/DavBfr/dart_pdf';

  final String author;

  final String creator;

  final String title;

  final String subject;

  final String keywords;

  final String producer;
}
