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
import '../format/dict.dart';
import '../format/string.dart';
import '../format/xref.dart';
import 'object.dart';

/// Information object
class PdfInfo extends PdfObject<PdfDict> {
  /// Create an information object
  PdfInfo(
    PdfDocument pdfDocument, {
    this.title,
    this.author,
    this.creator,
    this.subject,
    this.keywords,
    this.producer,
  }) : super(
          pdfDocument,
          params: PdfDict.values({
            if (author != null) '/Author': PdfString.fromString(author),
            if (creator != null) '/Creator': PdfString.fromString(creator),
            if (title != null) '/Title': PdfString.fromString(title),
            if (subject != null) '/Subject': PdfString.fromString(subject),
            if (keywords != null) '/Keywords': PdfString.fromString(keywords),
            if (producer != null)
              '/Producer': PdfString.fromString(
                  '$producer (${PdfXrefTable.libraryName})')
            else
              '/Producer': PdfString.fromString(PdfXrefTable.libraryName),
            '/CreationDate': PdfString.fromDate(DateTime.now()),
          }),
        );

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
