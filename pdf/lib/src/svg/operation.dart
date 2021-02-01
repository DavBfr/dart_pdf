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
import 'package:pdf/pdf.dart';
import 'package:xml/xml.dart';

import 'brush.dart';
import 'clip_path.dart';
import 'group.dart';
import 'image.dart';
import 'painter.dart';
import 'path.dart';
import 'symbol.dart';
import 'text.dart';
import 'transform.dart';
import 'use.dart';

abstract class SvgOperation {
  SvgOperation(this.brush, this.clip, this.transform, this.painter);

  static SvgOperation? fromXml(
      XmlElement element, SvgPainter painter, SvgBrush brush) {
    if (element.getAttribute('visibility') == 'hidden') {
      return null;
    }

    if (element.getAttribute('display') == 'none') {
      return null;
    }

    switch (element.name.local) {
      case 'circle':
        return SvgPath.fromCircleXml(element, painter, brush);
      case 'ellipse':
        return SvgPath.fromEllipseXml(element, painter, brush);
      case 'g':
        return SvgGroup.fromXml(element, painter, brush);
      case 'image':
        return SvgImg.fromXml(element, painter, brush);
      case 'line':
        return SvgPath.fromLineXml(element, painter, brush);
      case 'path':
        return SvgPath.fromXml(element, painter, brush);
      case 'polygon':
        return SvgPath.fromPolygonXml(element, painter, brush);
      case 'polyline':
        return SvgPath.fromPolylineXml(element, painter, brush);
      case 'rect':
        return SvgPath.fromRectXml(element, painter, brush);
      case 'symbol':
        return SvgSymbol.fromXml(element, painter, brush);
      case 'text':
        return SvgText.fromXml(element, painter, brush);
      case 'use':
        return SvgUse.fromXml(element, painter, brush);
    }

    return null;
  }

  final SvgBrush brush;

  final SvgClipPath clip;

  final SvgTransform transform;

  final SvgPainter painter;

  void paint(PdfGraphics canvas) {
    canvas.saveContext();
    clip.apply(canvas);
    if (transform.isNotEmpty) {
      canvas.setTransform(transform.matrix!);
    }
    if (brush.opacity! < 1.0 || brush.blendMode != null) {
      canvas.setGraphicState(PdfGraphicState(
        opacity: brush.opacity == 1 ? null : brush.opacity,
        blendMode: brush.blendMode,
      ));
    }
    if (brush.mask != null) {
      brush.mask!.apply(canvas);
    }
    paintShape(canvas);
    canvas.restoreContext();
  }

  @protected
  void paintShape(PdfGraphics canvas);

  void draw(PdfGraphics canvas) {
    canvas.saveContext();
    if (transform.isNotEmpty) {
      canvas.setTransform(transform.matrix!);
    }
    drawShape(canvas);
    canvas.restoreContext();
  }

  @protected
  void drawShape(PdfGraphics canvas);

  PdfRect boundingBox();
}
