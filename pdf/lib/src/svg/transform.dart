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

      // tryParse, not parse: a non-numeric argument used to throw a
      // FormatException out of pdf.save(). SvgParser.splitDoubles is left alone
      // because viewBox and path data share it.
      final parameterList = _tryParseAll(m.group(2)!);
      if (parameterList == null) {
        continue;
      }

      // SVG 1.1 7.6 gives each function an exact argument count. None of them
      // was checked: matrix() with seven arguments handed List.filled a negative
      // length and threw a RangeError, matrix() with fewer was zero-padded into a
      // singular matrix that collapsed everything after it, and the other five
      // indexed parameterList[0] on a list that could be empty. A function that
      // does not match its own signature is now skipped, and the valid ones
      // around it still apply.
      switch (name) {
        case 'matrix':
          if (parameterList.length != 6) {
            continue;
          }

          mat.multiply(
            Matrix4(
              parameterList[0],
              parameterList[1],
              0,
              0,
              parameterList[2],
              parameterList[3],
              0,
              0,
              0,
              0,
              1,
              0,
              parameterList[4],
              parameterList[5],
              0,
              1,
            ),
          );
          break;
        case 'translate':
          if (parameterList.isEmpty || parameterList.length > 2) {
            continue;
          }

          final dx = parameterList[0];
          final dy = parameterList.length > 1 ? parameterList[1] : 0.0;

          mat.multiply(Matrix4.identity()..translateByDouble(dx, dy, 0, 1));
          break;
        case 'scale':
          if (parameterList.isEmpty || parameterList.length > 2) {
            continue;
          }

          final sw = parameterList[0];
          final sh = parameterList.length > 1 ? parameterList[1] : sw;

          mat.multiply(Matrix4.identity()..scaleByDouble(sw, sh, 1, 1));
          break;
        case 'rotate':
          if (parameterList.length != 1 && parameterList.length != 3) {
            continue;
          }

          final degrees = parameterList[0];

          var ox = 0.0;
          var oy = 0.0;
          if (parameterList.length == 3) {
            // Rotation about the origin (ox, oy)
            ox = parameterList[1];
            oy = parameterList[2];
            mat.translateByDouble(ox, oy, 0, 1);
          }

          mat.multiply(Matrix4.rotationZ(radians(degrees)));

          if (ox != 0 || oy != 0) {
            mat.translateByDouble(-ox, -oy, 0, 1);
          }
          break;

        case 'skewX':
          if (parameterList.length != 1) {
            continue;
          }

          mat.multiply(Matrix4.skewX(radians(parameterList[0])));
          break;
        case 'skewY':
          if (parameterList.length != 1) {
            continue;
          }

          mat.multiply(Matrix4.skewY(radians(parameterList[0])));
          break;
      }
    }

    return SvgTransform(mat);
  }

  /// Every number in [parameters], or null when one of the tokens is not one.
  static List<double>? _tryParseAll(String parameters) {
    final result = <double>[];

    for (final token in parameters.split(RegExp(r'[\s,]+'))) {
      if (token.isEmpty) {
        continue;
      }

      final value = double.tryParse(token);
      if (value == null) {
        return null;
      }
      result.add(value);
    }

    return result;
  }

  final Matrix4? matrix;

  bool get isEmpty => matrix == null;

  bool get isNotEmpty => matrix != null;

  static const none = SvgTransform(null);

  static final _transformRegExp = RegExp(
    r'(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)\s*',
  );
}
