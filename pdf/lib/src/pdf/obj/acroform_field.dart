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
import '../format/array.dart';
import '../format/dict.dart';
import '../format/string.dart';
import 'annotation.dart';
import 'object.dart';

/// One interactive form field, with the widget annotations that display it as
/// its kids.
///
/// ISO 32000-1 12.7.3.1 allows a field and its widget to share one dictionary
/// only when the field has a single widget. This package wrote that merged form
/// always, so two widgets sharing a field name - a `TextField` in a `MultiPage`
/// header, say - became one root field per page with the same `/T` and different
/// `/V`: Acrobat listed the name once per page, an FDF export held one entry
/// each, and validators flagged the file.
class PdfAcroFormField extends PdfObject<PdfDict> {
  PdfAcroFormField(PdfDocument pdfDocument, {required this.fieldName})
    : super(pdfDocument, params: PdfDict());

  /// The partial field name every kid shares.
  final String fieldName;

  /// The widget annotations that display this field.
  final kids = <PdfAnnot>[];

  @override
  void prepare() {
    super.prepare();

    params['/T'] = PdfString.fromString(fieldName);
    params['/Kids'] = PdfArray.fromObjects(kids);
  }
}
