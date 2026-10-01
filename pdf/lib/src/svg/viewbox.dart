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

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';

/// How a viewBox is fitted into a viewport: SVG 1.1 7.8, `preserveAspectRatio`.
class SvgPreserveAspectRatio {
  const SvgPreserveAspectRatio({
    this.alignX = 0.5,
    this.alignY = 0.5,
    this.scale = SvgViewBoxScale.meet,
  });

  /// Parse a `preserveAspectRatio` attribute.
  ///
  /// Anything unrecognised falls back to the default, `xMidYMid meet`, which is
  /// what an absent attribute means.
  factory SvgPreserveAspectRatio.fromString(String? value) {
    if (value == null) {
      return const SvgPreserveAspectRatio();
    }

    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty && word != 'defer')
        .toList();

    if (words.isEmpty) {
      return const SvgPreserveAspectRatio();
    }

    if (words.first == 'none') {
      return const SvgPreserveAspectRatio(scale: SvgViewBoxScale.none);
    }

    final align = _aligns[words.first];
    if (align == null) {
      return const SvgPreserveAspectRatio();
    }

    return SvgPreserveAspectRatio(
      alignX: align.x,
      alignY: align.y,
      scale: words.length > 1 && words[1] == 'slice'
          ? SvgViewBoxScale.slice
          : SvgViewBoxScale.meet,
    );
  }

  static const _aligns = <String, PdfPoint>{
    'xMinYMin': PdfPoint(0, 0),
    'xMidYMin': PdfPoint(0.5, 0),
    'xMaxYMin': PdfPoint(1, 0),
    'xMinYMid': PdfPoint(0, 0.5),
    'xMidYMid': PdfPoint(0.5, 0.5),
    'xMaxYMid': PdfPoint(1, 0.5),
    'xMinYMax': PdfPoint(0, 1),
    'xMidYMax': PdfPoint(0.5, 1),
    'xMaxYMax': PdfPoint(1, 1),
  };

  /// Where the fitted content sits in the viewport, 0 to 1 on each axis.
  final double alignX;

  final double alignY;

  final SvgViewBoxScale scale;

  @override
  String toString() => '$runtimeType $alignX $alignY $scale';
}

enum SvgViewBoxScale {
  /// Scale uniformly so the whole viewBox is visible.
  meet,

  /// Scale uniformly so the viewBox covers the whole viewport.
  slice,

  /// Scale each axis independently to fill the viewport exactly.
  none,
}

/// The transform that puts [viewBox] into [viewport], in SVG user space.
///
/// [viewport] is the rectangle the content has to appear in, in the coordinates
/// of whatever contains it. Nothing in `src/svg` implemented this: a `<symbol>`
/// drew its children at their own scale, and a `<use>`'s width and height were
/// parsed and then ignored.
Matrix4 svgViewBoxTransform(
  PdfRect viewBox,
  PdfRect viewport,
  SvgPreserveAspectRatio preserveAspectRatio,
) {
  if (viewBox.width <= 0 || viewBox.height <= 0) {
    return Matrix4.translationValues(viewport.x, viewport.y, 0);
  }

  var scaleX = viewport.width / viewBox.width;
  var scaleY = viewport.height / viewBox.height;

  switch (preserveAspectRatio.scale) {
    case SvgViewBoxScale.meet:
      scaleX = scaleY = math.min(scaleX, scaleY);
      break;
    case SvgViewBoxScale.slice:
      scaleX = scaleY = math.max(scaleX, scaleY);
      break;
    case SvgViewBoxScale.none:
      break;
  }

  // Whatever the uniform scale leaves over is distributed by the alignment.
  final dx =
      viewport.x +
      (viewport.width - viewBox.width * scaleX) * preserveAspectRatio.alignX;
  final dy =
      viewport.y +
      (viewport.height - viewBox.height * scaleY) * preserveAspectRatio.alignY;

  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scaleX, scaleY, 1, 1)
    ..translateByDouble(-viewBox.x, -viewBox.y, 0, 1);
}
