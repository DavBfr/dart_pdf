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
import '../format/dict.dart';
import '../format/dict_stream.dart';
import '../format/name.dart';
import '../format/stream.dart';
import 'object.dart';

/// Stream Object
class PdfObjectStream extends PdfObject<PdfDict> {
  /// Constructs a stream object to store some data
  PdfObjectStream(
    PdfDocument pdfDocument, {
    String? type,
    this.isBinary = false,
  }) : super(
          pdfDocument,
          params: PdfDict.values({
            if (type != null) '/Type': PdfName(type),
          }),
        );

  /// This holds the stream's content.
  final PdfStream buf = PdfStream();

  /// defines if the stream needs to be converted to ascii85
  final bool isBinary;

  @override
  void writeContent(PdfStream s) {
    PdfDictStream(
      isBinary: isBinary,
      values: params.values,
      data: buf.output(),
    ).output(this, s, pdfDocument.settings.verbose ? 0 : null);
    s.putByte(0x0a);
  }
}
