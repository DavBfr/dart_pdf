/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

import 'document.dart';
import 'format/object_base.dart';

/// Base class for loading an existing PDF document.
abstract class PdfDocumentParserBase {
  /// Create a Document loader instance
  PdfDocumentParserBase(this.bytes);

  /// The existing PDF document content
  final Uint8List bytes;

  /// The objects size of the existing PDF document
  int get size;

  /// The offset of the previous cross reference table
  int get xrefOffset;

  PdfVersion get version => PdfVersion.pdf_1_4;

  /// Import the existing objects into the new PDF document
  void mergeDocument(PdfDocument pdfDocument);
}
