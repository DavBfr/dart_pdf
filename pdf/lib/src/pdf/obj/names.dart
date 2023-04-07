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
import '../format/array.dart';
import '../format/base.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../format/null_value.dart';
import '../format/num.dart';
import '../format/string.dart';
import 'object.dart';
import 'page.dart';

/// Pdf Name object
class PdfNames extends PdfObject<PdfDict> {
  /// This constructs a Pdf Name object
  PdfNames(PdfDocument pdfDocument) : super(pdfDocument, params: PdfDict());

  final Map<String, PdfDataType> _dests = <String, PdfDataType>{};

  /// Add a named destination
  void addDest(
    String name,
    PdfPage page, {
    double? posX,
    double? posY,
    double? posZ,
  }) {
    assert(page.pdfDocument == pdfDocument);

    _dests[name] = PdfDict({
      '/D': PdfArray([
        page.ref(),
        const PdfName('/XYZ'),
        if (posX == null) const PdfNull() else PdfNum(posX),
        if (posY == null) const PdfNull() else PdfNum(posY),
        if (posZ == null) const PdfNull() else PdfNum(posZ),
      ]),
    });
  }

  @override
  void prepare() {
    super.prepare();

    final dests = PdfArray();

    final keys = _dests.keys.toList()..sort();

    for (final name in keys) {
      dests.add(PdfString.fromString(name));
      dests.add(_dests[name]!);
    }

    final dict = PdfDict();
    if (dests.values.isNotEmpty) {
      dict['/Names'] = dests;
      dict['/Limits'] = PdfArray([
        PdfString.fromString(keys.first),
        PdfString.fromString(keys.last),
      ]);
    }
    params['/Dests'] = dict;
  }
}
