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

class PDFImage extends PDFXObject {
  final Image _img;
  String _name;

  final bool _alphaChannel;

  /// Creates a new <code>PDFImage</code> instance.
  ///
  /// @param img an <code>Image</code> value
  /// @param x an <code>int</code> value
  /// @param y an <code>int</code> value
  /// @param w an <code>int</code> value
  /// @param h an <code>int</code> value
  /// @param obs an <code>ImageObserver</code> value
  PDFImage(PDFDocument pdfDocument, this._img, [this._alphaChannel = false]) : super(pdfDocument, "/Image", isBinary: true) {
    _name = "/Image$objser";
    params["/Width"] = PDFStream.string(_img.width.toString());
    params["/Height"] = PDFStream.string(_img.height.toString());
    params["/BitsPerComponent"] = PDFStream.intNum(8);
    params['/Name'] = PDFStream.string(_name);

    if (_alphaChannel == false && _img.numChannels == 4) {
      var _sMask = new PDFImage(pdfDocument, this._img, true);
      params["/SMask"] = PDFStream.string("${_sMask.objser} 0 R");
    }

    if (_alphaChannel) {
      params["/ColorSpace"] = PDFStream.string("/DeviceGray");
    } else {
      params["/ColorSpace"] = PDFStream.string("/DeviceRGB");
    }

    // write the pixels to the stream
    // print("Processing image ${img.width}x${img.height} pixels");

    int w = _img.width;
    int h = _img.height;
    int s = w * h;

    Uint8List out = new Uint8List(_alphaChannel ? s : s * 3);

    if (_alphaChannel) {
      for (int i = 0; i < s; i++) {
        final p = _img.data[i];
        final int alpha = (p >> 24) & 0xff;

        out[i] = alpha;
      }
    } else {
      for (int i = 0; i < s; i++) {
        final p = _img.data[i];
        final int blue = (p >> 16) & 0xff;
        final int green = (p >> 8) & 0xff;
        final int red = p & 0xff;

        out[i * 3] = red;
        out[i * 3 + 1] = green;
        out[i * 3 + 2] = blue;
      }
    }

    buf.putBytes(out);
  }

  /// Get the value of width.
  /// @return value of width.
  int get width => _img.width;

  /// Get the value of height.
  /// @return value of height.
  int get height => _img.height;

  /// Get the name
  ///
  /// @return a <code>String</code> value
  String get name => _name;
}
