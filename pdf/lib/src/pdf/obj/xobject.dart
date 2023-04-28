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

  String get name => 'X$objser';
}
