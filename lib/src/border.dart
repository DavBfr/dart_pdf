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

class PDFBorder extends PDFObject {
  /// The style of the border
  final int style;

  /// The width of the border
  final double width;

  /// This array allows the definition of a dotted line for the border
  final List<double> dash;

  /// Creates a border using the predefined styles in PDFAnnot.
  /// <p>Note: Do not use PDFAnnot.DASHED with this method.
  /// Use the other constructor.
  ///
  /// @param width The width of the border
  /// @param style The style of the border
  /// @param dash The line pattern definition
  /// @see PDFAnnot
  PDFBorder(PDFDocument pdfDocument, this.width, {this.style = 0, this.dash}) : super(pdfDocument);

  /// @param os OutputStream to send the object to
  @override
  void writeContent(PDFStream os) {
    super.writeContent(os);

    var data = new List<PDFStream>();
    data.add(PDFStream.string("/S"));
    data.add(PDFStream.string("/" + "SDBIU".substring(style, style + 1)));
    data.add(PDFStream.string("/W $width"));
    if (dash != null) {
      data.add(PDFStream.string("/D"));
      data.add(PDFStream.array(dash.map((double d) => PDFStream.num(d))));
    }
    os.putArray(data);
  }
}
