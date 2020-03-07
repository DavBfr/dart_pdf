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

  void putByte(int s) {
    _stream.add(s);
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

  int get offset => _stream.length;

  List<int> output() => _stream;
}
