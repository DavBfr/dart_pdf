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

import 'dart:math' as math;

import '../document.dart';
import 'object_stream.dart';

/// Unicode character map object
class PdfUnicodeCmap extends PdfObjectStream {
  /// Create a Unicode character map object
  PdfUnicodeCmap(PdfDocument pdfDocument, this.protect) : super(pdfDocument);

  /// PDF 32000-1 9.10.3 allows no more than this many entries in one section.
  static const _maxBfCharPerSection = 100;

  /// List of characters
  final cmap = <int>[0];

  /// Protects the text from being "seen" by the PDF reader.
  final bool protect;

  @override
  void prepare() {
    if (protect) {
      cmap.fillRange(1, cmap.length, 0x20);
    }

    buf.putString(
      '/CIDInit/ProcSet\nfindresource begin\n'
      '12 dict begin\n'
      'begincmap\n'
      '/CIDSystemInfo<<\n'
      '/Registry (Adobe)\n'
      '/Ordering (UCS)\n'
      '/Supplement 0\n'
      '>> def\n'
      '/CMapName/Adobe-Identity-UCS def\n'
      '/CMapType 2 def\n'
      '1 begincodespacerange\n'
      '<0000> <FFFF>\n'
      'endcodespacerange\n',
    );

    // At most 100 entries per section: PDF 32000-1 9.10.3 caps it, and this used
    // to emit one section for the whole font.
    for (var start = 0; start < cmap.length; start += _maxBfCharPerSection) {
      final end = math.min(start + _maxBfCharPerSection, cmap.length);
      buf.putString('${end - start} beginbfchar\n');

      for (var key = start; key < end; key++) {
        buf.putString('<${_hex4(key)}> <${_utf16BeHex(cmap[key])}>\n');
      }

      buf.putString('endbfchar\n');
    }

    buf.putString(
      'endcmap\n'
      'CMapName currentdict /CMap defineresource pop\n'
      'end\n'
      'end',
    );
    super.prepare();
  }

  static String _hex4(int value) =>
      value.toRadixString(16).toUpperCase().padLeft(4, '0');

  /// A Unicode scalar value as the UTF-16BE code units the format requires.
  ///
  /// The destination used to be the code point padded to four digits, so
  /// anything above U+FFFF came out as five: U+1F100 was written <1F100>, which a
  /// reader decodes as U+1F10 followed by a NUL. Copy, in-viewer search and text
  /// extraction all returned the wrong characters for emoji and CJK ext-B, while
  /// the glyphs still rendered - so nothing looked wrong.
  static String _utf16BeHex(int rune) {
    if (rune <= 0xFFFF) {
      return _hex4(rune);
    }

    final value = rune - 0x10000;
    final high = 0xD800 + (value >> 10);
    final low = 0xDC00 + (value & 0x3FF);
    return '${_hex4(high)}${_hex4(low)}';
  }
}
