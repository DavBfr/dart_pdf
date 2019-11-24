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

enum PdfBorderStyle {
  /// Solid border. The border is drawn as a solid line.
  solid,

  /// The border is drawn with a dashed line.
  dashed,

  /// The border is drawn in a beveled style (faux three-dimensional) such
  /// that it looks as if it is pushed out of the page (opposite of INSET)
  beveled,

  /// The border is drawn in an inset style (faux three-dimensional) such
  /// that it looks as if it is inset into the page (opposite of BEVELED)
  inset,

  /// The border is drawn as a line on the bottom of the annotation rectangle
  underlined
}

class PdfBorder extends PdfObject {
  /// Creates a border using the predefined styles in [PdfAnnot].
  /// Note: Do not use [PdfAnnot.dashed] with this method.
  /// Use the other constructor.
  ///
  /// @param width The width of the border
  /// @param style The style of the border
  /// @param dash The line pattern definition
  /// @see [PdfAnnot]
  PdfBorder(
    PdfDocument pdfDocument,
    this.width, {
    this.style = PdfBorderStyle.solid,
    this.dash,
  })  : assert(width != null),
        assert(style != null),
        super(pdfDocument);

  /// The style of the border
  final PdfBorderStyle style;

  /// The width of the border
  final double width;

  /// This array allows the definition of a dotted line for the border
  final List<double> dash;

  /// @param os OutputStream to send the object to
  @override
  void _writeContent(PdfStream os) {
    super._writeContent(os);

    final List<PdfStream> data = <PdfStream>[];
    data.add(PdfStream.string('/S'));
    data.add(PdfStream.string(
        '/' + 'SDBIU'.substring(style.index, style.index + 1)));
    data.add(PdfStream.string('/W $width'));
    if (dash != null) {
      data.add(PdfStream.string('/D'));
      data.add(PdfStream.array(dash.map((double d) => PdfStream.num(d))));
    }
    os.putArray(data);
  }
}
