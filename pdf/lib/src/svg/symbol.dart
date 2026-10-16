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

class SvgSymbol extends SvgGroup {
  SvgSymbol(
    Iterable<SvgOperation> children,
    this.viewBox,
    this.preserveAspectRatio,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(children, brush, clip, transform, painter);

  factory SvgSymbol.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush, {
    Set<String> expanding = const <String>{},
  }) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    // A <use> may not reference one of its own ancestors - SVG 1.1 calls that an
    // error - so this element's id joins the set its children are built with.
    // Without it, '<g id="a"><rect/><use href="#a"/></g>' drew the rect a second
    // time before the guard below stopped the third.
    final id = element.getAttribute('id');
    final inside = id == null ? expanding : <String>{...expanding, id};

    final children = element.children
        .whereType<XmlElement>()
        .map<SvgOperation?>(
          (child) =>
              SvgOperation.fromXml(child, painter, _brush, expanding: inside),
        )
        .whereType<SvgOperation>();

    return SvgSymbol(
      children,
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

  /// The coordinate system this symbol's children are drawn in, if it declares
  /// one. Neither this nor [preserveAspectRatio] used to be read at all, so a
  /// symbol drew its children at their own scale wherever it was used.
  final PdfRect? viewBox;

  final SvgPreserveAspectRatio preserveAspectRatio;

  @override
  void paintShape(PdfGraphics canvas) {
    for (final child in children) {
      child.paint(canvas);
    }
  }
}
