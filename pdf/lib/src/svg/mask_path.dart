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
import 'operation.dart';
import 'painter.dart';

@immutable
class SvgMaskPath {
  const SvgMaskPath(this.children, this.painter);

  static SvgMaskPath fromXml(
      XmlElement element, SvgPainter painter, SvgBrush brush) {
    final maskPathAttr = element.getAttribute('mask');
    if (maskPathAttr == null) {
      return null;
    }

    Iterable<SvgOperation> children;

    if (maskPathAttr.startsWith('url(#')) {
      final id = maskPathAttr.substring(5, maskPathAttr.lastIndexOf(')'));
      final maskPath = painter.parser.findById(id);
      if (maskPath != null) {
        final maskBrush = SvgBrush.fromXml(maskPath, brush, painter);
        children = maskPath.children.whereType<XmlElement>().map<SvgOperation>(
            (c) => SvgOperation.fromXml(c, painter, maskBrush));
        return SvgMaskPath(children, painter);
      }
    }

    return null;
  }

  final Iterable<SvgOperation> children;

  final SvgPainter painter;

  void apply(PdfGraphics canvas) {
    final mask = PdfSoftMask(
      painter.document,
      boundingBox: painter.boundingBox,
    );

    final maskCanvas = mask.getGraphics();
    // maskCanvas.setTransform(canvas.getTransform());

    for (final child in children) {
      child.paint(maskCanvas);
    }

    canvas.setGraphicState(PdfGraphicState(softMask: mask));
  }
}
