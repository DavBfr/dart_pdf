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
import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../svg/painter.dart';
import '../svg/parser.dart';

class SvgImage extends Widget {
  factory SvgImage({
    @required String svg,
    BoxFit fit = BoxFit.contain,
    bool clip = true,
    double width,
    double height,
  }) {
    assert(clip != null);

    final xml = XmlDocument.parse(svg);
    final parser = SvgParser(xml: xml);

    return SvgImage._fromPainter(
      parser,
      fit,
      clip,
      width,
      height,
    );
  }

  SvgImage._fromPainter(
    this._svgParser,
    this.fit,
    this.clip,
    this.width,
    this.height,
  )   : assert(_svgParser != null),
        assert(fit != null);

  final SvgParser _svgParser;

  final BoxFit fit;

  final bool clip;

  final double width;

  final double height;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = width != null || _svgParser.width != null
        ? constraints.constrainWidth(width ?? _svgParser.width)
        : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.constrainWidth(_svgParser.viewBox.width);
    final h = height != null || _svgParser.height != null
        ? constraints.constrainHeight(height ?? _svgParser.height)
        : constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.constrainHeight(_svgParser.viewBox.height);

    final sizes = applyBoxFit(
        fit,
        PdfPoint(_svgParser.viewBox.width, _svgParser.viewBox.height),
        PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translate(
      box.x,
      box.y + box.height,
    );
    mat.scale(
      box.width / _svgParser.viewBox.width,
      -box.height / _svgParser.viewBox.height,
    );
    mat.translate(
      -_svgParser.viewBox.x,
      -_svgParser.viewBox.y,
    );
    context.canvas.saveContext();
    if (clip) {
      context.canvas
        ..drawBox(box)
        ..clipPath();
    }
    context.canvas.setTransform(mat);

    final painter = SvgPainter(
      _svgParser,
      context.canvas,
      context.document,
      PdfRect(
        0,
        0,
        context.page.pageFormat.width,
        context.page.pageFormat.height,
      ),
    );
    painter.paint();
    context.canvas.restoreContext();
  }
}
