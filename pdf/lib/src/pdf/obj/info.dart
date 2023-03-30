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

import '../document.dart';
import '../format/string.dart';
import 'object_dict.dart';

/// Information object
class PdfInfo extends PdfObjectDict {
  /// Create an information object
  PdfInfo(PdfDocument pdfDocument,
      {this.title,
      this.author,
      this.creator,
      this.subject,
      this.keywords,
      this.producer})
      : super(pdfDocument) {
    if (author != null) {
      params['/Author'] = PdfString.fromString(author!);
    }
    if (creator != null) {
      params['/Creator'] = PdfString.fromString(creator!);
    }
    if (title != null) {
      params['/Title'] = PdfString.fromString(title!);
    }
    if (subject != null) {
      params['/Subject'] = PdfString.fromString(subject!);
    }
    if (keywords != null) {
      params['/Keywords'] = PdfString.fromString(keywords!);
    }
    if (producer != null) {
      params['/Producer'] = PdfString.fromString('$producer ($_libraryName)');
    } else {
      params['/Producer'] = PdfString.fromString(_libraryName);
    }

    params['/CreationDate'] = PdfString.fromDate(DateTime.now());
  }

  static const String _libraryName = 'https://github.com/DavBfr/dart_pdf';

  /// Author of this document
  final String? author;

  /// Creator of this document
  final String? creator;

  /// Title of this document
  final String? title;

  /// Subject of this document
  final String? subject;

  /// Keywords of this document
  final String? keywords;

  /// Application that created this document
  final String? producer;
}
