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

import 'dart:io';
import 'dart:typed_data';

abstract class PdfStream {
  void putByte(int s);

  void putBytes(List<int> s);

  void setBytes(int offset, Iterable<int> iterable);

  void putStream(PdfStreamBuffer s);

  int get offset;

  void putString(String? s) {
    assert(() {
      for (final codeUnit in s!.codeUnits) {
        if (codeUnit > 0x7f) {
          return false;
        }
      }
      return true;
    }());
    putBytes(s!.codeUnits);
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

class PdfStreamBuffer extends PdfStream {
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

  @override
  void putByte(int s) {
    _ensureCapacity(1);
    _stream[_offset++] = s;
  }

  @override
  void putBytes(List<int> s) {
    _ensureCapacity(s.length);
    _stream.setAll(_offset, s);
    _offset += s.length;
  }

  @override
  void setBytes(int offset, Iterable<int> iterable) {
    _stream.setAll(offset, iterable);
  }

  @override
  void putStream(PdfStreamBuffer s) {
    putBytes(s._stream);
  }

  @override
  int get offset => _offset;

  Uint8List output() => _stream.sublist(0, _offset);
}

class PdfStreamFile extends PdfStream {
  PdfStreamFile(File file) {
    _raf = file.openSync(mode: FileMode.write);
  }

  late RandomAccessFile _raf;

  void close() {
    _raf.closeSync();
  }

  @override
  void putByte(int s) {
    _raf.writeByteSync(s);
  }

  @override
  void putBytes(List<int> s) {
    _raf.writeFromSync(s);
  }

  @override
  void setBytes(int offset, Iterable<int> iterable) {
    final originalOffset = _raf.positionSync();
    _raf.setPositionSync(offset);
    _raf.writeFromSync(iterable.toList());
    _raf.setPositionSync(originalOffset);
  }

  @override
  void putStream(PdfStreamBuffer s) {
    putBytes(s._stream);
  }

  @override
  int get offset {
    return _raf.positionSync();
  }
}
