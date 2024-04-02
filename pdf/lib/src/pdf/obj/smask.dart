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
import '../format/array.dart';
import '../format/bool.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../graphics.dart';
import '../rect.dart';
import 'function.dart';
import 'graphic_stream.dart';

class PdfSoftMask {
  PdfSoftMask(this.document,
      {required PdfRect boundingBox,
      bool isolated = false,
      bool knockout = false,
      bool invert = false}) {
    _mask = PdfGraphicXObject(document, '/Form');
    _mask.params['/BBox'] = PdfArray.fromNum([
      boundingBox.x,
      boundingBox.y,
      boundingBox.width,
      boundingBox.height,
    ]);
    if (isolated) {
      _mask.params['/I'] = const PdfBool(true);
    }
    if (knockout) {
      _mask.params['/K'] = const PdfBool(true);
    }
    _graphics = PdfGraphics(_mask, _mask.buf);

    if (invert) {
      _tr = PdfFunction(
        document,
        data: [255, 0],
      );
    }
  }

  final PdfDocument document;

  late PdfGraphicXObject _mask;

  PdfGraphics? _graphics;

  PdfGraphics? getGraphics() => _graphics;

  PdfBaseFunction? _tr;

  @override
  String toString() => '$runtimeType';

  PdfDict output() {
    final params = PdfDict.values({
      '/S': const PdfName('/Luminosity'),
      '/G': _mask.ref(),
    });

    if (_tr != null) {
      params['/TR'] = _tr!.ref();
    }

    return params;
  }
}
