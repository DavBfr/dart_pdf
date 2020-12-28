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

import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import 'brush.dart';
import 'clip_path.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

class SvgText extends SvgOperation {
  SvgText(
    this.x,
    this.y,
    this.dx,
    this.text,
    this.font,
    this.tspan,
    this.metrics,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(brush, clip, transform, painter);

  factory SvgText.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush, [
    PdfPoint offset = PdfPoint.zero,
  ]) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final dx =
        SvgParser.getNumeric(element, 'dx', _brush, defaultValue: 0).sizeValue;
    final dy =
        SvgParser.getNumeric(element, 'dy', _brush, defaultValue: 0).sizeValue;
    final x = SvgParser.getNumeric(element, 'x', _brush)?.sizeValue;
    final y = SvgParser.getNumeric(element, 'y', _brush)?.sizeValue;

    final text = element.children
        .where((node) => node is XmlText || node is XmlCDATA)
        .map((node) => node.text)
        .join()
        .trim();

    final font = painter.getFontCache(
        _brush.fontFamily, _brush.fontStyle, _brush.fontWeight);
    final pdfFont = font.getFont(Context(document: painter.document));
    final metrics = pdfFont.stringMetrics(text) * _brush.fontSize.sizeValue;
    offset = PdfPoint((x ?? offset.x) + dx, (y ?? offset.y) + dy);

    switch (_brush.textAnchor) {
      case SvgTextAnchor.start:
        break;
      case SvgTextAnchor.middle:
        offset = PdfPoint(offset.x - metrics.width / 2, offset.y);
        break;
      case SvgTextAnchor.end:
        offset = PdfPoint(offset.x - metrics.width, offset.y);
        break;
    }

    var childOffset = PdfPoint(offset.x + metrics.advanceWidth, offset.y);

    final tspan = element.children.whereType<XmlElement>().map<SvgText>((e) {
      final child = SvgText.fromXml(e, painter, _brush, childOffset);
      childOffset = PdfPoint(child.x + child.dx, child.y);
      return child;
    });

    return SvgText(
      offset.x,
      offset.y,
      metrics.advanceWidth,
      text,
      pdfFont,
      tspan,
      metrics,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double x;

  final double y;

  final double dx;

  final String text;

  final PdfFont font;

  final PdfFontMetrics metrics;

  final Iterable<SvgText> tspan;

  @override
  void paintShape(PdfGraphics canvas) {
    canvas
      ..saveContext()
      ..setTransform(Matrix4.identity()
        ..scale(1.0, -1.0)
        ..translate(x, -y));

    if (brush.fill.isNotEmpty) {
      brush.fill.setFillColor(this, canvas);
      if (brush.fillOpacity < 1) {
        canvas
          ..saveContext()
          ..setGraphicState(PdfGraphicState(opacity: brush.fillOpacity));
      }
      canvas.drawString(font, brush.fontSize.sizeValue, text, 0, 0);
      if (brush.fillOpacity < 1) {
        canvas.restoreContext();
      }
    }

    if (brush.stroke.isNotEmpty) {
      if (brush.strokeWidth != null) {
        canvas.setLineWidth(brush.strokeWidth.sizeValue);
      }
      if (brush.strokeDashArray != null) {
        canvas.setLineDashPattern(brush.strokeDashArray);
      }
      if (brush.strokeOpacity < 1) {
        canvas.setGraphicState(PdfGraphicState(opacity: brush.strokeOpacity));
      }
      brush.stroke.setStrokeColor(this, canvas);
      canvas.drawString(font, brush.fontSize.sizeValue, text, 0, 0,
          mode: PdfTextRenderingMode.stroke);
    }

    canvas.restoreContext();

    for (final span in tspan) {
      span.paint(canvas);
    }
  }

  @override
  void drawShape(PdfGraphics canvas) {
    canvas
      ..saveContext()
      ..setTransform(Matrix4.identity()
        ..scale(1.0, -1.0)
        ..translate(x, -y))
      ..drawString(font, brush.fontSize.sizeValue, text, 0, 0,
          mode: PdfTextRenderingMode.clip)
      ..restoreContext();

    for (final span in tspan) {
      span.draw(canvas);
    }
  }

  @override
  PdfRect boundingBox() {
    final b = metrics.toPdfRect();
    var x = b.x, y = b.y, w = b.width, h = b.height;
    for (final child in tspan) {
      final b = child.boundingBox();
      x = min(b.x, x);
      y = min(b.y, y);
      w = max(b.width, w);
      h = max(b.height, w);
    }

    return PdfRect(x, y, w, h);
  }
}
