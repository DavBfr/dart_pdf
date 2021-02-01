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
import 'package:xml/xml.dart';

import 'brush.dart';
import 'clip_path.dart';
import 'group.dart';
import 'operation.dart';
import 'painter.dart';
import 'transform.dart';

class SvgSymbol extends SvgGroup {
  SvgSymbol(
    Iterable<SvgOperation> children,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(children, brush, clip, transform, painter);

  factory SvgSymbol.fromXml(
      XmlElement element, SvgPainter painter, SvgBrush brush) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    final children = element.children
        .whereType<XmlElement>()
        .map<SvgOperation?>(
            (child) => SvgOperation.fromXml(child, painter, _brush))
        .whereType<SvgOperation>();

    return SvgSymbol(
      children,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  @override
  void paintShape(PdfGraphics canvas) {
    for (final child in children) {
      child.paint(canvas);
    }
  }
}
