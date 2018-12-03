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

class PdfStream {
  final _stream = List<int>();

  void putStream(PdfStream s) {
    _stream.addAll(s._stream);
  }

  void putString(String s) {
    for (int codeUnit in s.codeUnits) {
      if (codeUnit <= 0x7f) {
        _stream.add(codeUnit);
      } else {
        _stream.add(0x20);
      }
    }
  }

  static PdfStream string(String s) => PdfStream()..putString(s);

  void putStringUtf16(String s) {
    for (int codeUnit in s.codeUnits) {
      _stream.add(codeUnit & 0xff);
      _stream.add((codeUnit >> 8) & 0xff);
    }
  }

  void putBytes(List<int> s) {
    _stream.addAll(s);
  }

  void putNum(double d) {
    putString(d.toString());
  }

  static PdfStream num(double d) => PdfStream()..putNum(d);
  static PdfStream intNum(int i) => PdfStream()..putString(i.toString());

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

  void putTextUtf16(String s, bool bom) {
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

    putBytes(latin1.encode('('));
    if (bom) putBytes([0xfe, 0xff]);
    putBytes(encodeUtf16be(s));
    putBytes(latin1.encode(')'));
  }

  static PdfStream text(String s) => PdfStream()..putText(s);

  static PdfStream textUtf16(String s, bool bom) =>
      PdfStream()..putTextUtf16(s, bom);

  void putBool(bool value) {
    putString(value ? "true" : "false");
  }

  void putArray(List<PdfStream> values) {
    putString("[");
    for (var val in values) {
      putStream(val);
      putString(" ");
    }
    putString("]");
  }

  void putObjectArray(List<PdfObject> values) {
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

  static PdfStream array(List<PdfStream> values) =>
      PdfStream()..putArray(values);

  void putDictionary(Map<String, PdfStream> values) {
    putString("<< ");
    values.forEach((k, v) {
      putString("$k ");
      putStream(v);
      putString("\n");
    });
    putString(">>");
  }

  static PdfStream dictionary(Map<String, PdfStream> values) =>
      PdfStream()..putDictionary(values);

  void putObjectDictionary(Map<String, PdfObject> values) {
    putString("<< ");
    values.forEach((k, v) {
      putString("$k ");
      putStream(v.ref());
      putString(" ");
    });
    putString(">>");
  }

  int get offset => _stream.length;

  List<int> output() => _stream;
}
