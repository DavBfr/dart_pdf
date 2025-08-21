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

import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
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
    this.fontSpans,
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
        SvgParser.getNumeric(element, 'dx', _brush, defaultValue: 0)!.sizeValue;
    final dy =
        SvgParser.getNumeric(element, 'dy', _brush, defaultValue: 0)!.sizeValue;
    final x = SvgParser.getNumeric(element, 'x', _brush)?.sizeValue;
    final y = SvgParser.getNumeric(element, 'y', _brush)?.sizeValue;

    final text = element.children
        .where((node) => node is XmlText || node is XmlCDATA)
        .map((node) => node.value)
        .join()
        .trim();

    final pdfFont = painter.getFontCache(_brush.fontFamily!, _brush.fontStyle!, _brush.fontWeight!);
    final fontSpans = _createFontSpans(text, pdfFont, painter.fallbackFontsTtf, fontSize: brush.fontSize!.sizeValue, letterSpacing: null);
    final metrics = PdfFontMetrics.append(fontSpans.map((span) => span.font.stringMetrics(span.text) * _brush.fontSize!.sizeValue));

    var baselineOffset = 0.0;
    // Only ideographic is supported
    switch (_brush.dominantBaseline) {
      case SvgDominantBaseline.ideographic:
        baselineOffset = metrics.descent;
        break;
      default:
        break;
    }

    offset =
        PdfPoint((x ?? offset.x) + dx, (y ?? offset.y) + dy + baselineOffset);

    switch (_brush.textAnchor!) {
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
      childOffset = PdfPoint(child.x! + child.dx, child.y! + baselineOffset);
      return child;
    });

    return SvgText(
      offset.x,
      offset.y,
      metrics.advanceWidth,
      fontSpans,
      tspan,
      metrics,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  final double? x;

  final double? y;

  final double dx;

  final PdfFontMetrics metrics;

  final Iterable<SvgText> tspan;

  final List<FontSpan> fontSpans;

  @override
  void paintShape(PdfGraphics canvas) {
    canvas
      ..saveContext()
      ..setTransform(Matrix4.identity()
        ..scale(1.0, -1.0)
        ..translate(x, -y!));

    if (brush.fill!.isNotEmpty) {
      brush.fill!.setFillColor(this, canvas);
      if (brush.fillOpacity! < 1) {
        canvas
          ..saveContext()
          ..setGraphicState(PdfGraphicState(opacity: brush.fillOpacity));
      }
      _drawFontSpans(canvas);
      if (brush.fillOpacity! < 1) {
        canvas.restoreContext();
      }
    }

    if (brush.stroke!.isNotEmpty) {
      if (brush.strokeWidth != null) {
        canvas.setLineWidth(brush.strokeWidth!.sizeValue);
      }
      if (brush.strokeDashArray != null) {
        canvas.setLineDashPattern(brush.strokeDashArray!);
      }
      if (brush.strokeOpacity! < 1) {
        canvas.setGraphicState(PdfGraphicState(opacity: brush.strokeOpacity));
      }
      brush.stroke!.setStrokeColor(this, canvas);
      _drawFontSpans(canvas, mode: PdfTextRenderingMode.stroke);
    }

    canvas.restoreContext();

    for (final span in tspan) {
      span.paint(canvas);
    }
  }

  void _drawFontSpans(PdfGraphics canvas, {PdfTextRenderingMode mode = PdfTextRenderingMode.fill}) {
    var x = 0.0;
    for (final span in fontSpans) {
      canvas.drawString(span.font, brush.fontSize!.sizeValue, span.text, x, 0,
          mode: mode);
      x += span.width;
    }
  }

  @override
  void drawShape(PdfGraphics canvas) {
    canvas
      ..saveContext()
      ..setTransform(Matrix4.identity()
        ..scale(1.0, -1.0)
        ..translate(x, -y!));
    _drawFontSpans(canvas, mode: PdfTextRenderingMode.clip);
    canvas.restoreContext();

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

class RunesAndFont {
  RunesAndFont(this.runes, this.font);

  final List<int> runes;
  final PdfFont font;

  @override
  String toString() =>
      '(`${String.fromCharCodes(runes)}` ($runes) ${font.fontName})';

  void append(RunesAndFont other) {
    assert(isCompatible(other));
    runes.addAll(other.runes);
  }

  bool isCompatible(RunesAndFont other) => font == other.font;
}

class FontSpan {
  FontSpan(this.text, this.font, this.width);

  factory FontSpan.fromRunesAndFont(RunesAndFont raf,
      {required double fontSize, double? letterSpacing}) {
    const textScaleFactor = 1.0;
    final width = raf.font
            .stringMetrics(String.fromCharCodes(raf.runes),
                letterSpacing:
                    (letterSpacing ?? 0.0) / (fontSize * textScaleFactor))
            .advanceWidth *
        (fontSize * textScaleFactor);
    return FontSpan(String.fromCharCodes(raf.runes), raf.font, width);
  }

  final String text;
  final PdfFont font;
  final double width;
}

List<FontSpan> _createFontSpans(
    String text, PdfFont primaryFont, List<PdfTtfFont> fallbackFonts,
    {required double fontSize, double? letterSpacing}) {
  final runes = text.runes.toList();
  final runesAndFonts = _groupRunes(runes, primaryFont, fallbackFonts);
  return runesAndFonts
      .map((raf) => FontSpan.fromRunesAndFont(raf,
          fontSize: fontSize, letterSpacing: letterSpacing))
      .toList();
}

String _getFontSubFamily(PdfFont font) {
  if (font is PdfTtfFont) {
    return font.font
            .getNameID(TtfParserName.fontSubfamily)
            ?.toLowerCase()
            .trim() ??
        'regular';
  }
  final name = font.fontName;
  if (name.endsWith('-Bold')) {
    return 'bold';
  }
  return 'regular';
}

List<RunesAndFont> _groupRunes(
    List<int> runes, PdfFont primaryFont, List<PdfTtfFont> fallbackFonts) {
  final primaryFontSubFamily = _getFontSubFamily(primaryFont);

  // Current, primary, fonts with same sub-family, fonts with different sub-family, null
  final orderedFonts = <PdfFont?>[
    primaryFont,
    primaryFont,
    ...fallbackFonts.where((f) => _getFontSubFamily(f) == primaryFontSubFamily),
    ...fallbackFonts.where((f) => _getFontSubFamily(f) != primaryFontSubFamily),
    null
  ];

  // Is there a font that supports all runes?
  // Skip first one because it's given twice in the ordered fonts
  final allSupportedFont = orderedFonts.skip(1).firstWhere(
      (f) => runes.every((rune) => f?.isRuneSupported(rune) == true),
      orElse: () => null);
  if (allSupportedFont != null) {
    return [RunesAndFont(runes, allSupportedFont)];
  }

  // Split into groups of runes that can be rendered with the same font
  final runesAndFonts = <RunesAndFont>[];
  for (final rune in runes) {
    final font =
        orderedFonts.firstWhere((f) => f?.isRuneSupported(rune) != false);
    if (font != null) {
      runesAndFonts.add(RunesAndFont([rune], font));
      orderedFonts[0] = font;
    } else {
      runesAndFonts.add(RunesAndFont('?'.runes.toList(), primaryFont));
    }
  }

  if (runesAndFonts.isEmpty) {
    return [];
  }

  final groups = [runesAndFonts.first];
  for (final raf in runesAndFonts.skip(1)) {
    if (raf.isCompatible(groups.last)) {
      groups.last.append(raf);
    } else {
      groups.add(raf);
    }
  }

  return groups;
}
