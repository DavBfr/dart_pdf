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

  /// Escape special characters
  /// \ddd Character code ddd (octal)
  void putTextBytes(List<int> s) {
    for (var c in s) {
      switch (c) {
        case 0x0a: // \n Line feed (LF)
          _stream.add(0x5c);
          _stream.add(0x6e);
          break;
        case 0x0d: // \r Carriage return (CR)
          _stream.add(0x5c);
          _stream.add(0x72);
          break;
        case 0x09: // \t Horizontal tab (HT)
          _stream.add(0x5c);
          _stream.add(0x74);
          break;
        case 0x08: // \b Backspace (BS)
          _stream.add(0x5c);
          _stream.add(0x62);
          break;
        case 0x0c: // \f Form feed (FF)
          _stream.add(0x5c);
          _stream.add(0x66);
          break;
        case 0x28: // \( Left parenthesis
          _stream.add(0x5c);
          _stream.add(0x28);
          break;
        case 0x29: // \) Right parenthesis
          _stream.add(0x5c);
          _stream.add(0x29);
          break;
        case 0x5c: // \\ Backslash
          _stream.add(0x5c);
          _stream.add(0x5c);
          break;
        default:
          _stream.add(c);
      }
    }
  }

  void putText(String s) {
    putBytes(latin1.encode('('));
    putTextBytes(latin1.encode(s));
    putBytes(latin1.encode(')'));
  }

  void putTextUtf16(String s) {
    putBytes(latin1.encode('('));
    putTextBytes(encodeUtf16be(s));
    putBytes(latin1.encode(')'));
  }

  void putLitteral(String s) {
    putBytes(latin1.encode('('));
    putBytes([0xfe, 0xff]);
    putTextBytes(encodeUtf16be(s));
    putBytes(latin1.encode(')'));
  }

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
