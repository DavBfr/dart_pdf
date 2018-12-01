/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
  /// The style of the border
  final PdfBorderStyle style;

  /// The width of the border
  final double width;

  /// This array allows the definition of a dotted line for the border
  final List<double> dash;

  /// Creates a border using the predefined styles in [PdfAnnot].
  /// Note: Do not use [PdfAnnot.dashed] with this method.
  /// Use the other constructor.
  ///
  /// @param width The width of the border
  /// @param style The style of the border
  /// @param dash The line pattern definition
  /// @see [PdfAnnot]
  PdfBorder(PdfDocument pdfDocument, this.width,
      {this.style = PdfBorderStyle.solid, this.dash})
      : super(pdfDocument);

  /// @param os OutputStream to send the object to
  @override
  void _writeContent(PdfStream os) {
    super._writeContent(os);

    var data = List<PdfStream>();
    data.add(PdfStream.string("/S"));
    data.add(PdfStream.string(
        "/" + "SDBIU".substring(style.index, style.index + 1)));
    data.add(PdfStream.string("/W $width"));
    if (dash != null) {
      data.add(PdfStream.string("/D"));
      data.add(PdfStream.array(dash.map((double d) => PdfStream.num(d))));
    }
    os.putArray(data);
  }
}
