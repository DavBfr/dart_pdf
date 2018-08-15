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

class PDFStream {
  final _stream = new BytesBuilder(copy: false);

  void putStream(PDFStream s) {
    _stream.add(s._stream.toBytes());
  }

  void putString(String s) {
    for (int codeUnit in s.codeUnits) {
      if (codeUnit <= 0x7f) {
        _stream.addByte(codeUnit);
      } else {
        _stream.addByte(0x20);
      }
    }
  }

  static PDFStream string(String s) => new PDFStream()..putString(s);

  void putStringUtf16(String s) {
    for (int codeUnit in s.codeUnits) {
      _stream.addByte(codeUnit & 0xff);
      _stream.addByte((codeUnit >> 8) & 0xff);
    }
  }

  void putBytes(List<int> s) {
    _stream.add(s);
  }

  void putNum(double d) {
    putString(d.toString());
  }

  static PDFStream num(double d) => new PDFStream()..putNum(d);
  static PDFStream intNum(int i) => new PDFStream()..putString(i.toString());

  void putText(String s) {
    // Escape special characters
    //    \n Line feed (LF)
    //    \r Carriage return (CR)
    //    \t Horizontal tab (HT)
    //    \b Backspace (BS)
    //    \f Form feed (FF)
    //    \( Left parenthesis
    //    \) Right parenthesis
    //    \\ Backslash
    //    \ddd Character code ddd (octal)
    s = s
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\n', '\\n')
        .replaceAll('\t', '\\t')
        .replaceAll('\b', '\\b')
        .replaceAll('\f', '\\f')
        .replaceAll('\r', '\\r');

    putBytes(latin1.encode('(' + s + ')'));
  }

  static PDFStream text(String s) => new PDFStream()..putText(s);

  void putBool(bool value) {
    putString(value ? "true" : "false");
  }

  void putArray(List<PDFStream> values) {
    putString("[");
    for (var val in values) {
      putStream(val);
      putString(" ");
    }
    putString("]");
  }

  void putObjectArray(List<PDFObject> values) {
    putString("[");
    for (var val in values) {
      putStream(val.ref());
      putString(" ");
    }
    putString("]");
  }

  void putStringArray(List<dynamic> values) {
    putString("[" + values.join(" ") + "]");
  }

  static PDFStream array(List<PDFStream> values) =>
      new PDFStream()..putArray(values);

  void putDictionary(Map<String, PDFStream> values) {
    putString("<< ");
    values.forEach((k, v) {
      putString("$k ");
      putStream(v);
      putString("\n");
    });
    putString(">>");
  }

  static PDFStream dictionary(Map<String, PDFStream> values) =>
      new PDFStream()..putDictionary(values);

  void putObjectDictionary(Map<String, PDFObject> values) {
    putString("<< ");
    values.forEach((k, v) {
      putString("$k ");
      putStream(v.ref());
      putString(" ");
    });
    putString(">>");
  }

  int get offset => _stream.length;

  Uint8List output() => _stream.toBytes();
}
