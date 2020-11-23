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

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import 'brush.dart';
import 'clip_path.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

class SvgUse extends SvgOperation {
  SvgUse(
    this.x,
    this.y,
    this.width,
    this.height,
    this.href,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(brush, clip, transform, painter);

  factory SvgUse.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush,
  ) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final width =
        SvgParser.getNumeric(element, 'width', _brush, defaultValue: 0)
            .sizeValue;
    final height =
        SvgParser.getNumeric(element, 'height', _brush, defaultValue: 0)
            .sizeValue;
    final x =
        SvgParser.getNumeric(element, 'x', _brush, defaultValue: 0).sizeValue;
    final y =
        SvgParser.getNumeric(element, 'y', _brush, defaultValue: 0).sizeValue;

    SvgOperation href;
    final hrefAttr = element.getAttribute('href') ??
        element.getAttribute('href', namespace: 'http://www.w3.org/1999/xlink');

    if (hrefAttr != null) {
      final hrefElement = painter.parser.findById(hrefAttr.substring(1));
      if (hrefElement != null) {
        href = SvgOperation.fromXml(hrefElement, painter, _brush);
      }
    }

    return SvgUse(
      x,
      y,
      width,
      height,
      href,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double x;

  final double y;

  final double width;

  final double height;

  final SvgOperation href;

  @override
  void paintShape(PdfGraphics canvas) {
    if (x != 0 || y != 0) {
      canvas.setTransform(Matrix4.translationValues(x, y, 0));
    }
    href?.paint(canvas);
  }

  @override
  void drawShape(PdfGraphics canvas) {
    if (x != 0 || y != 0) {
      canvas.setTransform(Matrix4.translationValues(x, y, 0));
    }
    href?.draw(canvas);
  }

  @override
  PdfRect boundingBox() => href.boundingBox();
}
