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

import '../../pdf.dart';
import 'brush.dart';
import 'clip_path.dart';
import 'group.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';
import 'viewbox.dart';

/// An `<svg>` element inside another one.
///
/// It establishes a viewport of its own, which is why it is not just a group.
/// `SvgOperation.fromXml` had no case for it at all, so the whole subtree was
/// dropped - silently, with siblings still drawing, which users report as a
/// missing icon.
class SvgNestedSvg extends SvgGroup {
  SvgNestedSvg(
    Iterable<SvgOperation> children,
    this.x,
    this.y,
    this.width,
    this.height,
    this.viewBox,
    this.preserveAspectRatio,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(children, brush, clip, transform, painter);

  factory SvgNestedSvg.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush, {
    Set<String> expanding = const <String>{},
  }) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final x = SvgParser.getNumeric(
      element,
      'x',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.horizontal);
    final y = SvgParser.getNumeric(
      element,
      'y',
      _brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.vertical);

    // Absent means 100% of the parent viewport, as SVG 1.1 5.1.2 says.
    final width = SvgParser.getNumeric(
      element,
      'width',
      _brush,
    )?.sizeIn(painter.viewport, SvgAxis.horizontal);
    final height = SvgParser.getNumeric(
      element,
      'height',
      _brush,
    )?.sizeIn(painter.viewport, SvgAxis.vertical);

    final id = element.getAttribute('id');
    final inside = id == null ? expanding : <String>{...expanding, id};

    final children = element.children
        .whereType<XmlElement>()
        .where((element) => element.name.local != 'symbol')
        .map<SvgOperation?>(
          (child) =>
              SvgOperation.fromXml(child, painter, _brush, expanding: inside),
        )
        .whereType<SvgOperation>();

    return SvgNestedSvg(
      children,
      x,
      y,
      width,
      height,
      SvgParser.getViewBox(element),
      SvgPreserveAspectRatio.fromString(
        element.getAttribute('preserveAspectRatio'),
      ),
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double x;

  final double y;

  /// Null means the whole of the parent viewport.
  final double? width;

  final double? height;

  final PdfRect? viewBox;

  final SvgPreserveAspectRatio preserveAspectRatio;

  /// The box this element gives its content, in the current user space.
  PdfRect get viewport =>
      PdfRect(x, y, width ?? painter.viewport.x, height ?? painter.viewport.y);

  /// Clip to the viewport and fit the viewBox into it, then hand back the
  /// viewport size that is in force inside.
  PdfPoint? _enter(PdfGraphics canvas) {
    final box = viewport;
    if (box.width <= 0 || box.height <= 0) {
      return null; // width="0" or height="0" disables rendering.
    }

    // overflow:hidden is the initial value for a nested <svg>, and the clip goes
    // on before the viewBox transform so it is in the coordinates it was written
    // in.
    canvas
      ..drawRect(box.x, box.y, box.width, box.height)
      ..clipPath();

    final box2 = viewBox;
    if (box2 == null) {
      if (x != 0 || y != 0) {
        canvas.setTransform(Matrix4.translationValues(x, y, 0));
      }
      return PdfPoint(box.width, box.height);
    }

    canvas.setTransform(svgViewBoxTransform(box2, box, preserveAspectRatio));
    return box2.size;
  }

  @override
  void paintShape(PdfGraphics canvas) {
    final inner = _enter(canvas);
    if (inner == null) {
      return;
    }

    painter.withViewport(inner, () {
      for (final child in children) {
        child.paint(canvas);
      }
    });
  }

  @override
  void drawShape(PdfGraphics canvas) {
    final inner = _enter(canvas);
    if (inner == null) {
      return;
    }

    painter.withViewport(inner, () {
      for (final child in children) {
        child.draw(canvas);
      }
    });
  }
}
