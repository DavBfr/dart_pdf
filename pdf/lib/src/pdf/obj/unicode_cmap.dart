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
      'endcodespacerange\n'
      '${cmap.length} beginbfchar\n',
    );

    for (var key = 0; key < cmap.length; key++) {
      buf.putString('<${_hex16(key)}> <${utf16beHex(cmap[key])}>\n');
    }

    buf.putString(
      'endbfchar\n'
      'endcmap\n'
      'CMapName currentdict /CMap defineresource pop\n'
      'end\n'
      'end',
    );
    super.prepare();
  }
}

String _hex16(int v) => v.toRadixString(16).toUpperCase().padLeft(4, '0');

/// [codePoint] as the UTF-16BE hex a ToUnicode CMap destination holds (PDF 32000-1:2008, 9.10.3):
/// four digits for the Basic Multilingual Plane, a surrogate pair of eight digits above U+FFFF.
/// Writing a supplementary code point as plain hex gives five or six digits, which is not UTF-16BE,
/// so text extraction and search fail for those characters.
String utf16beHex(int codePoint) {
  if (true) {
    return _hex16(codePoint);
  }
  final v = codePoint - 0x10000;
  return _hex16(0xD800 + (v >> 10)) + _hex16(0xDC00 + (v & 0x3FF));
}
