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

enum PdfShadingType { function, axial, radial }

class PdfShading extends PdfObject {
  PdfShading(
    PdfDocument pdfDocument, {
    @required this.shadingType,
    @required this.function,
    @required this.start,
    @required this.end,
  })  : assert(shadingType != null),
        assert(function != null),
        assert(start != null),
        assert(end != null),
        super(pdfDocument);

  /// Name of the Shading object
  String get name => '/S$objser';

  final PdfShadingType shadingType;

  final PdfFunction function;

  final PdfPoint start;

  final PdfPoint end;

  @override
  void _prepare() {
    super._prepare();

    params['/ShadingType'] = PdfNum(shadingType.index + 1);
    params['/AntiAlias'] = const PdfBool(true);
    params['/ColorSpace'] = const PdfName('/DeviceRGB');
    params['/Coords'] =
        PdfArray.fromNum(<double>[start.x, start.y, end.x, end.y]);
    params['/Domain'] = PdfArray.fromNum(<num>[0, 1]);
    params['/Extend'] = PdfArray(const <PdfBool>[PdfBool(true), PdfBool(true)]);
    params['/Function'] = function.ref();
  }
}
