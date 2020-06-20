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

class PdfNames extends PdfObject {
  /// This constructs a Pdf Name object
  PdfNames(PdfDocument pdfDocument) : super(pdfDocument);

  final PdfArray _dests = PdfArray();

  void addDest(
    String name,
    PdfPage page, {
    double posX,
    double posY,
    double posZ,
  }) {
    assert(page.pdfDocument == pdfDocument);
    assert(name != null);

    _dests.add(PdfSecString.fromString(this, name));
    _dests.add(PdfDict(<String, PdfDataType>{
      '/D': PdfArray(<PdfDataType>[
        page.ref(),
        const PdfName('/XYZ'),
        if (posX == null) const PdfNull() else PdfNum(posX),
        if (posY == null) const PdfNull() else PdfNum(posY),
        if (posZ == null) const PdfNull() else PdfNum(posZ),
      ]),
    }));
  }

  @override
  void _prepare() {
    super._prepare();

    params['/Dests'] = PdfDict(<String, PdfDataType>{'/Names': _dests});
  }
}
