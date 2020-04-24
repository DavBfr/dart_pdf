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

// ignore_for_file: omit_local_variable_types

part of pdf;

class PdfFunction extends PdfObjectStream {
  PdfFunction(
    PdfDocument pdfDocument, {
    this.colors,
  }) : super(pdfDocument);

  final List<PdfColor> colors;

  @override
  void _prepare() {
    for (final PdfColor color in colors) {
      buf.putBytes(<int>[
        (color.red * 255.0).round() & 0xff,
        (color.green * 255.0).round() & 0xff,
        (color.blue * 255.0).round() & 0xff,
      ]);
    }

    super._prepare();

    params['/FunctionType'] = const PdfNum(0);
    params['/BitsPerSample'] = const PdfNum(8);
    params['/Order'] = const PdfNum(3);
    params['/Domain'] = PdfArray.fromNum(const <num>[0, 1]);
    params['/Range'] = PdfArray.fromNum(const <num>[0, 1, 0, 1, 0, 1]);
    params['/Size'] = PdfNum(colors.length);
  }
}
