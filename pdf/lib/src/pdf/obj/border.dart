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
import '../format/name.dart';
import '../format/num.dart';
import 'annotation.dart';
import 'object_dict.dart';

/// Border style
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

/// Defines a border object
class PdfBorder extends PdfObjectDict {
  /// Creates a border using the predefined styles in [PdfAnnot].
  PdfBorder(
    PdfDocument pdfDocument,
    this.width, {
    this.style = PdfBorderStyle.solid,
    this.dash,
  }) : super(pdfDocument);

  /// The style of the border
  final PdfBorderStyle style;

  /// The width of the border
  final double width;

  /// This array allows the definition of a dotted line for the border
  final List<double>? dash;

  @override
  void prepare() {
    super.prepare();

    params['/S'] =
        PdfName('/${'SDBIU'.substring(style.index, style.index + 1)}');
    params['/W'] = PdfNum(width);

    if (dash != null) {
      params['/D'] = PdfArray.fromNum(dash!);
    }
  }
}
