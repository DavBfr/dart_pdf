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

part of pdf;

class PdfStream {
  static const precision = 5;
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
    putString(d.toStringAsFixed(precision));
  }

  void putNumList(List<double> d) {
    putString(d.map((v) => v.toStringAsFixed(precision)).join(" "));
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

  void putLiteral(String s) {
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
