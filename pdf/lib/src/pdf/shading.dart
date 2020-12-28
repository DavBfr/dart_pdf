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

import 'package:meta/meta.dart';

import 'data_types.dart';
import 'document.dart';
import 'function.dart';
import 'object.dart';
import 'point.dart';
import 'rect.dart';

enum PdfShadingType { axial, radial }

class PdfShading extends PdfObject {
  PdfShading(
    PdfDocument pdfDocument, {
    @required this.shadingType,
    @required this.function,
    @required this.start,
    @required this.end,
    this.radius0,
    this.radius1,
    this.boundingBox,
    this.extendStart = false,
    this.extendEnd = false,
  })  : assert(shadingType != null),
        assert(function != null),
        assert(start != null),
        assert(end != null),
        assert(extendStart != null),
        assert(extendEnd != null),
        super(pdfDocument);

  /// Name of the Shading object
  String get name => '/S$objser';

  final PdfShadingType shadingType;

  final PdfBaseFunction function;

  final PdfPoint start;

  final PdfPoint end;

  final PdfRect boundingBox;

  final bool extendStart;

  final bool extendEnd;

  final double radius0;

  final double radius1;

  @override
  void prepare() {
    super.prepare();

    params['/ShadingType'] = PdfNum(shadingType.index + 2);
    if (boundingBox != null) {
      params['/BBox'] = PdfArray.fromNum(<double>[
        boundingBox.left,
        boundingBox.bottom,
        boundingBox.right,
        boundingBox.top,
      ]);
    }
    params['/AntiAlias'] = const PdfBool(true);
    params['/ColorSpace'] = const PdfName('/DeviceRGB');

    if (shadingType == PdfShadingType.axial) {
      params['/Coords'] =
          PdfArray.fromNum(<double>[start.x, start.y, end.x, end.y]);
    } else if (shadingType == PdfShadingType.radial) {
      assert(radius0 != null);
      assert(radius1 != null);
      params['/Coords'] = PdfArray.fromNum(
          <double>[start.x, start.y, radius0, end.x, end.y, radius1]);
    }
    // params['/Domain'] = PdfArray.fromNum(<num>[0, 1]);
    if (extendStart || extendEnd) {
      params['/Extend'] =
          PdfArray(<PdfBool>[PdfBool(extendStart), PdfBool(extendEnd)]);
    }
    params['/Function'] = function.ref();
  }
}
