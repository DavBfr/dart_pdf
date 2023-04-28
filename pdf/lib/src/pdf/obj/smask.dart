/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
