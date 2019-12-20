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

// ignore_for_file: omit_local_variable_types

part of pdf;

class PdfStream {
  static const int precision = 5;
  final List<int> _stream = <int>[];

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
    assert(d != double.infinity);
    putString(d.toStringAsFixed(precision));
  }

  void putNumList(List<double> d) {
    putString(d.map((double v) {
      assert(v != double.infinity);
      return v.toStringAsFixed(precision);
    }).join(' '));
  }

  void putIntList(List<int> d) {
    putString(d.map((int v) => v.toString()).join(' '));
  }

  static PdfStream num(double d) => PdfStream()..putNum(d);
  static PdfStream intNum(int i) => PdfStream()..putString(i.toString());

  /// Escape special characters
  /// \ddd Character code ddd (octal)
  void putTextBytes(List<int> s) {
    for (int c in s) {
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
    putBytes(<int>[0xfe, 0xff]);
    putTextBytes(encodeUtf16be(s));
    putBytes(latin1.encode(')'));
  }

  void putBool(bool value) {
    putString(value ? 'true' : 'false');
  }

  /// Returns the ASCII/Unicode code unit corresponding to the hexadecimal digit
  /// [digit].
  int _codeUnitForDigit(int digit) =>
      digit < 10 ? digit + 0x30 : digit + 0x61 - 10;

  void putBinary(List<int> s) {
    _stream.add(0x3c);
    for (int byte in s) {
      _stream.add(_codeUnitForDigit((byte & 0xF0) >> 4));
      _stream.add(_codeUnitForDigit(byte & 0x0F));
    }
    _stream.add(0x3e);
  }

  static PdfStream binary(List<int> s) => PdfStream()..putBinary(s);

  void putArray(List<PdfStream> values) {
    putString('[');
    for (PdfStream val in values) {
      putStream(val);
      putString(' ');
    }
    putString(']');
  }

  void putObjectArray(List<PdfObject> values) {
    putString('[');
    for (PdfObject val in values) {
      putStream(val.ref());
      putString(' ');
    }
    putString(']');
  }

  void putStringArray(List<String> values) {
    putString('[' + values.join(' ') + ']');
  }

  void putDate(DateTime date) {
    final DateTime utcDate = date.toUtc();
    final String year = utcDate.year.toString().padLeft(4, '0');
    final String month = utcDate.month.toString().padLeft(2, '0');
    final String day = utcDate.day.toString().padLeft(2, '0');
    final String hour = utcDate.hour.toString().padLeft(2, '0');
    final String minute = utcDate.minute.toString().padLeft(2, '0');
    final String second = utcDate.second.toString().padLeft(2, '0');
    putText('D:$year$month$day$hour$minute${second}Z');
  }

  void putNumArray(List<double> values) {
    putString('[');
    putNumList(values);
    putString(']');
  }

  void putIntArray(List<int> values) {
    putString('[');
    putIntList(values);
    putString(']');
  }

  static PdfStream array(List<PdfStream> values) =>
      PdfStream()..putArray(values);

  void putDictionary(Map<String, PdfStream> values) {
    putString('<< ');
    values.forEach((String k, PdfStream v) {
      putString('$k ');
      putStream(v);
      putString('\n');
    });
    putString('>>');
  }

  static PdfStream dictionary(Map<String, PdfStream> values) =>
      PdfStream()..putDictionary(values);

  void putObjectDictionary(Map<String, PdfObject> values) {
    putDictionary(values.map((String string, PdfObject object) =>
        MapEntry<String, PdfStream>(string, object.ref())));
  }

  int get offset => _stream.length;

  List<int> output() => _stream;
}
