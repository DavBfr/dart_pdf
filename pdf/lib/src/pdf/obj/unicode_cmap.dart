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
  final List<int> cmap = <int>[0];

  /// Protects the text from being "seen" by the PDF reader.
  final bool protect;

  @override
  void prepare() {
    if (protect) {
      cmap.fillRange(1, cmap.length, 0x20);
    }

    buf.putString('/CIDInit/ProcSet findresource begin\n'
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
        '${cmap.length} beginbfchar\n');

    for (var key = 0; key < cmap.length; key++) {
      final value = cmap[key];
      buf.putString('<' +
          key.toRadixString(16).toUpperCase().padLeft(4, '0') +
          '> <' +
          value.toRadixString(16).toUpperCase().padLeft(4, '0') +
          '>\n');
    }

    buf.putString('endbfchar\n'
        'endcmap\n'
        'CMapName currentdict /CMap defineresource pop\n'
        'end\n'
        'end');
    super.prepare();
  }
}
