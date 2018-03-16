/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PDFObjectStream extends PDFObject {
  /// This holds the stream's content.
  final PDFStream buf = new PDFStream();

  /// defines if the stream needs to be converted to ascii85
  final bool isBinary;

  /// Constructs a stream. The supplied type is stored in the stream's header
  /// and is used by other objects that extend the PDFStream class (like
  /// PDFImage).
  /// <p>By default, the stream will be compressed.
  /// @param type type for the stream
  /// @see PDFImage
  PDFObjectStream(PDFDocument pdfDocument, {String type, this.isBinary = false}) : super(pdfDocument, type);

  Uint8List _data;

  @override
  void prepare() {
    super.prepare();

    if (pdfDocument.deflate) {
      var z = new ZLibCodec(level: ZLibOption.MAX_LEVEL);
      _data = z.encode(buf.output());
      params["/Filter"] = PDFStream.string("/FlateDecode");
    } else if (isBinary) {
      // This is a Ascii85 stream
      var e = new Ascii85Encoder();
      _data = e.convert(buf.output());
      params["/Filter"] = PDFStream.string("/ASCII85Decode");
    } else {
      // This is a non-deflated stream
      _data = buf.output();
    }
    params["/Length"] = PDFStream.intNum(_data.length);
  }

  @override
  void writeContent(PDFStream os) {
    super.writeContent(os);

    os.putString("stream\n");
    os.putBytes(_data);
    os.putString("\nendstream\n");
  }
}
