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

part of pdf;

class PdfArrayObject extends PdfObject {
  PdfArrayObject(
    PdfDocument pdfDocument,
    this.array,
  )   : assert(array != null),
        super(pdfDocument);

  final PdfArray array;

  @override
  void _writeContent(PdfStream os) {
    super._writeContent(os);

    array.output(os);
    os.putBytes(<int>[0x0a]);
  }
}
