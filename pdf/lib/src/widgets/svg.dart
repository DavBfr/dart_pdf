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

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import '../../widgets.dart';
import '../svg/painter.dart';
import '../svg/parser.dart';

class SvgImage extends Widget {
  factory SvgImage({
    required String svg,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    bool clip = true,
    double? width,
    double? height,
    PdfColor? colorFilter,
    Map<String, List<Font>> fonts = const {},
    Font? defaultFont,
    List<Font> fallbackFonts = const [],
    SvgCustomFontLookup? customFontLookup,
  }) {
    try {
      final xml = XmlDocument.parse(svg);
      final parser = SvgParser(xml: xml, colorFilter: colorFilter);
      return SvgImage._fromParser(
        parser,
        fit,
        alignment,
        clip,
        width,
        height,
        fonts,
        defaultFont,
        fallbackFonts,
        customFontLookup,
      );
    } catch (e) {
      throw ArgumentError.value(svg, 'svg',
          'Invalid SVG\n`$svg`\nBase64: ${base64.encode(utf8.encode(svg))}\n$e}');
    }
  }

  SvgImage._fromParser(
    this._svgParser,
    this.fit,
    this.alignment,
    this.clip,
    this.width,
    this.height,
    this.fonts,
    this.defaultFont,
    this.fallbackFonts,
    this.customFontLookup,
  );

  final SvgParser _svgParser;

  final BoxFit fit;

  final Alignment alignment;

  final bool clip;

  final double? width;

  final double? height;

  Font? defaultFont;

  final Map<String, List<Font>> fonts;

  final List<Font> fallbackFonts;
  final SvgCustomFontLookup? customFontLookup;

  late FittedSizes sizes;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = width != null || _svgParser.width != null
        ? constraints.constrainWidth(width ?? _svgParser.width!)
        : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.constrainWidth(_svgParser.viewBox.width);
    final h = height != null || _svgParser.height != null
        ? constraints.constrainHeight(height ?? _svgParser.height!)
        : constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.constrainHeight(_svgParser.viewBox.height);

    sizes = applyBoxFit(fit, _svgParser.viewBox.size, PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination!);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final _alignment = Alignment(alignment.x, -alignment.y);
    final sourceRect = _alignment.inscribe(sizes.source!, _svgParser.viewBox);
    final sx = sizes.destination!.x / sizes.source!.x;
    final sy = sizes.destination!.y / sizes.source!.y;
    final dx = sourceRect.x * sx;
    final dy = sourceRect.y * sy;

    final mat = Matrix4.identity()
      ..translate(
        box!.x - dx,
        box!.y + dy + box!.height,
      )
      ..scale(sx, -sy);

    context.canvas.saveContext();
    if (clip) {
      context.canvas
        ..drawBox(box!)
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
      fonts,
      defaultFont,
      fallbackFonts,
      customFontLookup: customFontLookup,
    );
    painter.paint();
    context.canvas.restoreContext();
  }
}

@immutable
class DecorationSvgImage extends DecorationGraphic {
  const DecorationSvgImage({
    required this.svg,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String svg;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Context context, PdfRect box) {
    Widget.draw(
      SvgImage(svg: svg, fit: fit, alignment: alignment),
      offset: box.offset,
      context: context,
      constraints: BoxConstraints.tight(box.size),
    );
  }
}

typedef SvgCustomFontLookup = Font? Function(
    String fontFamily, String fontStyle, String fontWeight);
