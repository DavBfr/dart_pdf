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

import '../document.dart';
import 'object_stream.dart';

/// Unicode character map object
class PdfUnicodeCmap extends PdfObjectStream {
  /// Create a Unicode character map object
  PdfUnicodeCmap(PdfDocument pdfDocument, this.protect) : super(pdfDocument);

  /// List of characters
  final cmap = <int>[0];

  /// Protects the text from being "seen" by the PDF reader.
  final bool protect;

  // ToUnicode destination values are UTF-16BE, not raw UTF-32 scalar
  // values. Supplementary characters must be emitted as surrogate pairs.
  String _utf16Hex(int codepoint) {
    if (codepoint < 0 || codepoint > 0x10ffff) {
      throw FormatException('Invalid Unicode codepoint: $codepoint');
    }
    if (codepoint <= 0xffff) {
      return codepoint.toRadixString(16).toUpperCase().padLeft(4, '0');
    }
    final scalar = codepoint - 0x10000;
    final high = 0xd800 + (scalar >> 10);
    final low = 0xdc00 + (scalar & 0x3ff);
    return '${high.toRadixString(16).toUpperCase()}'
        '${low.toRadixString(16).toUpperCase()}';
  }

  @override
  void prepare() {
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

    // PDF CMap operators may contain at most 100 bfchar entries per block.
    for (var start = 0; start < cmap.length; start += 100) {
      final end = (start + 100 < cmap.length) ? start + 100 : cmap.length;
      buf.putString('${end - start} beginbfchar\n');
      for (var key = start; key < end; key++) {
        // Do not mutate cmap when protected. Font subsetting needs to retain
        // the original codepoint-to-glyph relationship during preparation.
        final value = protect && key != 0 ? 0x20 : cmap[key];
        final cid = key.toRadixString(16).toUpperCase().padLeft(4, '0');
        buf.putString('<$cid> <${_utf16Hex(value)}>\n');
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
}
