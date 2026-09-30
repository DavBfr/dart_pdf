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

import 'dart:typed_data';

class PdfStream {
  static const int _grow = 65536;

  Uint8List _stream = Uint8List(_grow);

  int _offset = 0;

  void _ensureCapacity(int size) {
    if (_stream.length - _offset >= size) {
      return;
    }

    final newSize = _offset + size + _grow;
    final newBuffer = Uint8List(newSize);
    newBuffer.setAll(0, _stream);
    _stream = newBuffer;
  }

  void putByte(int s) {
    _ensureCapacity(1);
    _stream[_offset++] = s;
  }

  void putBytes(List<int> s) {
    _ensureCapacity(s.length);
    _stream.setAll(_offset, s);
    _offset += s.length;
  }

  void setBytes(int offset, Iterable<int> iterable) {
    _stream.setAll(offset, iterable);
  }

  void putStream(PdfStream s) {
    putBytes(s._stream);
  }

  int get offset => _offset;

  Uint8List output() => _stream.sublist(0, _offset);

  void putString(String? s) {
    // An indexed scan, not a for-in over `codeUnits`: this assert runs on every
    // operator and number written to a content stream, and the CodeUnits
    // iterator (a closure plus a ListIterator per character) showed up as the
    // hottest single item in a debug-mode render profile. Asserts are compiled
    // out of release builds, so this only costs debug and JIT runs — which is
    // where `flutter run` lives.
    assert(_isAscii(s!));
    putBytes(s!.codeUnits);
  }

  static bool _isAscii(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) > 0x7f) {
        return false;
      }
    }
    return true;
  }

  void putComment(String s) {
    if (s.isEmpty) {
      putByte(0x0a);
    } else {
      for (final l in s.split('\n')) {
        if (l.isNotEmpty) {
          putBytes('% $l\n'.codeUnits);
        }
      }
    }
  }
}
