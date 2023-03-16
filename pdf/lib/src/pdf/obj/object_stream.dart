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

import '../document.dart';
import '../format/dict_stream.dart';
import '../format/stream.dart';
import 'object_dict.dart';

/// Stream Object
class PdfObjectStream extends PdfObjectDict {
  /// Constructs a stream object to store some data
  PdfObjectStream(
    PdfDocument pdfDocument, {
    String? type,
    this.isBinary = false,
  }) : super(pdfDocument, type: type);

  /// This holds the stream's content.
  final PdfStream buf = PdfStream();

  /// defines if the stream needs to be converted to ascii85
  final bool isBinary;

  @override
  void writeContent(PdfStream os) {
    PdfDictStream.values(
      object: this,
      isBinary: isBinary,
      values: params.values,
      data: buf.output(),
    ).output(os, pdfDocument.verbose ? 0 : null);
  }
}
