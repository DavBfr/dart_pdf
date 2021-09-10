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

import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import 'parser.dart';

class SvgTransform {
  const SvgTransform(this.matrix);

  factory SvgTransform.fromXml(XmlElement element) {
    return SvgTransform.fromString(element.getAttribute('transform'));
  }

  factory SvgTransform.fromString(String? transform) {
    if (transform == null) {
      return none;
    }

    final mat = Matrix4.identity();

    for (final m in _transformRegExp.allMatches(transform)) {
      final name = m.group(1);
      final parameterList = SvgParser.splitDoubles(m.group(2)!).toList();

      switch (name) {
        case 'matrix':
          final mm = <double>[
            ...parameterList,
            ...List.filled(6 - parameterList.length, 0.0)
          ];

          mat.multiply(Matrix4(mm[0], mm[1], 0, 0, mm[2], mm[3], 0, 0, 0, 0, 1,
              0, mm[4], mm[5], 0, 1));
          break;
        case 'translate':
          final dx = parameterList[0];
          final dy = [...parameterList, .0][1];

          mat.multiply(Matrix4.identity()..translate(dx, dy));
          break;
        case 'scale':
          final sw = parameterList[0];
          final sh = [...parameterList, sw][1];

          mat.multiply(Matrix4.identity()..scale(sw, sh));
          break;
        case 'rotate':
          final degrees = parameterList[0];

          var ox = 0.0;
          var oy = 0.0;
          if (parameterList.length > 1) {
            // Rotation about the origin (ox, oy)
            ox = parameterList[1];
            oy = [...parameterList, .0][2];
            mat.translate(ox, oy);
          }

          mat.multiply(Matrix4.rotationZ(radians(degrees)));

          if (ox != 0 || oy != 0) {
            mat.translate(-ox, -oy);
          }
          break;

        case 'skewX':
          // assert(false, 'skewX');
          mat.multiply(Matrix4.skewX(radians(parameterList[0])));
          break;
        case 'skewY':
          // assert(false, 'skewY');
          mat.multiply(Matrix4.skewY(radians(parameterList[0])));
          break;
      }
    }

    return SvgTransform(mat);
  }

  final Matrix4? matrix;

  bool get isEmpty => matrix == null;

  bool get isNotEmpty => matrix != null;

  static const none = SvgTransform(null);

  static final _transformRegExp =
      RegExp(r'(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)\s*');
}
