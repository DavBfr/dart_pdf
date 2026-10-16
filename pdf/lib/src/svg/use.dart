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
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'symbol.dart';
import 'transform.dart';
import 'viewbox.dart';

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
    SvgBrush brush, {
    Set<String> expanding = const <String>{},
  }) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    // Nullable, because a missing width means the whole viewport while an
    // explicit width="0" means render nothing. Both used to be parsed into dead
    // fields: paintShape applied a translation and nothing else.
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

    SvgOperation? href;
    final hrefAttr =
        element.getAttribute('href') ??
        element.getAttribute(
          'href',
          namespaceUri: 'http://www.w3.org/1999/xlink',
        );

    // Only a local '#id' reference, with an id in it: substring(1) on an empty
    // or external href read whatever happened to be there. And a reference to an
    // id already being expanded is a cycle - '<g id="a"><use href="#a"/></g>'
    // recursed until the isolate died with a StackOverflowError out of
    // pdf.save(), which is an Error and so slips through a try/catch around the
    // build. Such a <use> now simply paints nothing.
    if (hrefAttr != null &&
        hrefAttr.startsWith('#') &&
        hrefAttr.length > 1 &&
        !expanding.contains(hrefAttr.substring(1))) {
      final id = hrefAttr.substring(1);
      final hrefElement = painter.parser.findById(id);
      if (hrefElement != null) {
        href = SvgOperation.fromXml(
          hrefElement,
          painter,
          _brush,
          expanding: <String>{...expanding, id},
        );
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

  /// The width of the viewport this `<use>` establishes, or null for the whole
  /// of the current one.
  final double? width;

  final double? height;

  final SvgOperation? href;

  /// The box this `<use>` gives its content, in the current user space.
  PdfRect get viewport =>
      PdfRect(x, y, width ?? painter.viewport.x, height ?? painter.viewport.y);

  /// Whether this `<use>` establishes a viewport of its own, which only a
  /// `<symbol>` target does.
  SvgSymbol? get _symbol => href is SvgSymbol ? href! as SvgSymbol : null;

  /// Place the content, and hand back the viewport size in force inside it.
  PdfPoint? _position(PdfGraphics canvas) {
    final symbol = _symbol;
    if (symbol == null) {
      if (x != 0 || y != 0) {
        canvas.setTransform(Matrix4.translationValues(x, y, 0));
      }
      return null;
    }

    final box = viewport;
    if (box.width <= 0 || box.height <= 0) {
      return null; // width="0" renders nothing, per SVG 1.1 5.6.
    }

    // The symbol's content belongs inside this box - overflow:hidden - and its
    // viewBox, if it has one, is fitted into it.
    canvas
      ..drawRect(box.x, box.y, box.width, box.height)
      ..clipPath();

    final viewBox = symbol.viewBox;
    if (viewBox == null) {
      if (x != 0 || y != 0) {
        canvas.setTransform(Matrix4.translationValues(x, y, 0));
      }
      return PdfPoint(box.width, box.height);
    }

    canvas.setTransform(
      svgViewBoxTransform(viewBox, box, symbol.preserveAspectRatio),
    );
    return viewBox.size;
  }

  @override
  void paintShape(PdfGraphics canvas) {
    final symbol = _symbol;
    final inner = _position(canvas);
    if (symbol != null && inner == null) {
      return;
    }

    if (inner == null) {
      href?.paint(canvas);
      return;
    }

    painter.withViewport(inner, () => href!.paint(canvas));
  }

  @override
  void drawShape(PdfGraphics canvas) {
    final symbol = _symbol;
    final inner = _position(canvas);
    if (symbol != null && inner == null) {
      return;
    }

    if (inner == null) {
      href?.draw(canvas);
      return;
    }

    painter.withViewport(inner, () => href!.draw(canvas));
  }

  @override
  PdfRect boundingBox() => href?.boundingBox() ?? PdfRect.zero;
}
