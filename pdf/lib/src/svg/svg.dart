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

import 'dart:convert';

import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'brush.dart';
import 'clip_path.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

class EmbeddedSvg extends SvgOperation {
  EmbeddedSvg(
    this.children,
    this.width,
    this.height,
    this.parentWidth,
    this.parentHeight,
    this.x,
    this.y,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(brush, clip, transform, painter);

  factory EmbeddedSvg.fromXml(
      XmlElement element, SvgPainter painter, SvgBrush brush) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final parentWidth =
        SvgParser.getNumeric(element, 'width', _brush, defaultValue: 0)!
            .sizeValue;
    final parentHeight =
        SvgParser.getNumeric(element, 'height', _brush, defaultValue: 0)!
            .sizeValue;
    final x =
        SvgParser.getNumeric(element, 'x', _brush, defaultValue: 0)!.sizeValue;
    final y =
        SvgParser.getNumeric(element, 'y', _brush, defaultValue: 0)!.sizeValue;

    final hrefAttr = element.getAttribute('href') ??
        element.getAttribute('href', namespace: 'http://www.w3.org/1999/xlink');

    if (hrefAttr != null && hrefAttr.startsWith('data:image/svg+xml')) {
      final px = hrefAttr.substring(hrefAttr.indexOf(';') + 1);
      if (px.startsWith('base64,')) {
        final b = px.substring(7).replaceAll(RegExp(r'\s'), '');
        final bytes = base64.decode(b);

        final svgValue = utf8.decode(bytes);

        final xml = XmlDocument.parse(svgValue);
        final parser = SvgParser(
          xml: xml,
          colorFilter: painter.parser.colorFilter,
        );

        final children = parser.root.children
          .whereType<XmlElement>()
          .where((element) => element.name.local != 'symbol')
          .map<SvgOperation?>(
              (child) => SvgOperation.fromXml(child, painter, _brush))
          .whereType<SvgOperation>();

        return EmbeddedSvg(
          children,
          parser.width ?? parentWidth,
          parser.height ?? parentHeight,
          parentWidth,
          parentHeight,
          x,
          y,
          _brush,
          SvgClipPath.fromXml(element, painter, _brush),
          SvgTransform.fromXml(element),
          painter,
        );

      }
    }

    return EmbeddedSvg(
      [],
      parentWidth,
      parentHeight,
      parentWidth,
      parentHeight,
      x,
      y,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double x;

  final double y;

  final double parentWidth;
  final double width;

  final double parentHeight;
  final double height;

  final Iterable<SvgOperation> children;

  @override
  void paintShape(PdfGraphics canvas) {
    final sx = parentWidth / width;
    final sy = parentHeight / height;

    canvas
      ..saveContext()
      ..setTransform(Matrix4.identity()
        ..scale(sx, sy, 1.0)
        ..translate(x / sx, y / sy));

    for (final child in children) {
      child.paint(canvas);
    }

    canvas.restoreContext();
  }

  @override
  void drawShape(PdfGraphics canvas) {
    for (final child in children) {
      child.draw(canvas);
    }
  }

  @override
  PdfRect boundingBox() {
    return PdfRect(x, y, width, height);
  }
}
