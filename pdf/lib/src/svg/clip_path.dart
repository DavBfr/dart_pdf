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
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'brush.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';

@immutable
class SvgClipPath {
  const SvgClipPath(
    this.children,
    this.isEmpty,
    this.painter, {
    this.objectBoundingBox = false,
    this.evenOdd = false,
  });

  factory SvgClipPath.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush,
  ) {
    final clipPathAttr = element.getAttribute('clip-path');
    if (clipPathAttr == null) {
      return const SvgClipPath(null, true, null);
    }

    Iterable<SvgOperation?> children;

    if (clipPathAttr.startsWith('url(#')) {
      final id = clipPathAttr.substring(5, clipPathAttr.lastIndexOf(')'));
      final clipPath = painter.parser.findById(id);
      if (clipPath != null) {
        // clipPathUnits and clip-rule may be written in the style attribute, so
        // it has to be flattened before they are read. Neither was read at all:
        // objectBoundingBox fractions went out as user units, clipping the
        // artwork to about a one-unit sliver, and clip-rule="evenodd" was
        // ignored, so a donut crop filled its own hole.
        SvgParser.convertStyle(clipPath);

        children = clipPath.children.whereType<XmlElement>().map<SvgOperation?>(
          (c) => SvgOperation.fromXml(c, painter, brush),
        );

        return SvgClipPath(
          children,
          false,
          painter,
          objectBoundingBox:
              clipPath.getAttribute('clipPathUnits')?.trim() ==
              'objectBoundingBox',
          evenOdd: clipPath.getAttribute('clip-rule')?.trim() == 'evenodd',
        );
      }
    }

    return const SvgClipPath(null, true, null);
  }

  final Iterable<SvgOperation?>? children;

  final bool isEmpty;

  final SvgPainter? painter;

  /// Whether the clip path is written in fractions of the clipped element's own
  /// bounding box rather than in user units.
  final bool objectBoundingBox;

  /// Whether the clip uses the even-odd rule.
  final bool evenOdd;

  bool get isNotEmpty => !isEmpty;

  void apply(PdfGraphics canvas, PdfRect boundingBox) {
    if (isEmpty) {
      return;
    }

    if (!objectBoundingBox) {
      for (final child in children!) {
        child!.draw(canvas);
      }
      canvas.clipPath(evenOdd: evenOdd);
      return;
    }

    // An empty group's bounding box comes back as infinities, and a zero-area
    // one would scale the path to nothing: either way there is no region to
    // clip to, so clip everything away rather than write NaN into the stream.
    if (!boundingBox.width.isFinite ||
        !boundingBox.height.isFinite ||
        !boundingBox.left.isFinite ||
        !boundingBox.bottom.isFinite ||
        boundingBox.width <= 0 ||
        boundingBox.height <= 0) {
      canvas
        ..drawRect(0, 0, 0, 0)
        ..clipPath();
      return;
    }

    canvas.saveContext();
    canvas.setTransform(
      Matrix4.identity()
        ..translateByDouble(boundingBox.left, boundingBox.bottom, 0, 1)
        ..scaleByDouble(boundingBox.width, boundingBox.height, 1, 1),
    );
    for (final child in children!) {
      child!.draw(canvas);
    }
    canvas.restoreContext();
    canvas.clipPath(evenOdd: evenOdd);
  }
}
