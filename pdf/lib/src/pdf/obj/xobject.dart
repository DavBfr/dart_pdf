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
import '../format/name.dart';
import 'object_stream.dart';

class PdfXObject extends PdfObjectStream {
  PdfXObject(PdfDocument pdfDocument, String? subtype, {bool isBinary = false})
    : super(pdfDocument, type: '/XObject', isBinary: isBinary) {
    if (subtype != null) {
      params['/Subtype'] = PdfName(subtype);
    }
  }

  /// The key this object is registered under in a /XObject resource dictionary,
  /// and the operand that names it in a content stream.
  ///
  /// Includes the leading solidus, like every other resource name in this
  /// package. It used to be the only one that did not, so the dictionary key came
  /// out as a bare 'X4' - which poppler rejects as a non-name key, dropping the
  /// page - while the two form subclasses overrode it with a slash and the Do
  /// operand then came out as '//X4'.
  String get name => '/X$objser';
}
