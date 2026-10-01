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
import '../widgets/widget.dart';
import 'brush.dart';
import 'clip_path.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

/// One piece of text drawn at one place, with the style in force where it was
/// written.
class SvgTextRun {
  const SvgTextRun(
    this.text,
    this.x,
    this.y,
    this.font,
    this.metrics,
    this.brush,
  );

  final String text;

  final double x;

  final double y;

  final PdfFont font;

  final PdfFontMetrics metrics;

  final SvgBrush brush;

  SvgTextRun shifted(double dx) =>
      SvgTextRun(text, x + dx, y, font, metrics, brush);
}

/// The runs that share one text-anchor, in document order.
///
/// SVG calls this a text chunk: it starts at the `<text>` and at every element
/// that gives an absolute `x` or `y`, and the anchor shifts the whole of it at
/// once.
class _Chunk {
  _Chunk(this.anchor);

  final SvgTextAnchor anchor;

  final runs = <SvgTextRun>[];

  double get width => runs.fold<double>(
    0,
    (double sum, SvgTextRun run) => sum + run.metrics.advanceWidth,
  );
}

/// A `<text>` element and everything inside it.
///
/// This used to join and trim every text node of the element into one string and
/// then build a child SvgText per `<tspan>`, so `I Love<tspan>SVG</tspan>!` drew
/// 'I Love!' and then 'SVG' after the whole parent string: the runs lost their
/// place in the document, the space before the tspan was dropped, source
/// newlines were drawn literally, `<desc>` and `<title>` were rendered as text,
/// and the first tspan started at the parent's full advance width whatever came
/// before it.
class SvgText extends SvgOperation {
  SvgText(
    this.runs,
    SvgBrush brush,
    SvgClipPath clip,
    SvgTransform transform,
    SvgPainter painter,
  ) : super(brush, clip, transform, painter);

  factory SvgText.fromXml(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush,
  ) {
    final _brush = SvgBrush.fromXml(element, brush, painter);

    // One cursor for the whole <text>, moved along by each run that is emitted.
    final cursor = _Cursor(painter);
    final chunks = <_Chunk>[];

    _walk(element, painter, _brush, cursor, chunks, root: true);

    // text-anchor shifts a whole chunk, and by its advance width - the ink
    // extent it used to be given is a different number, so centring was off by
    // the side bearings.
    final runs = <SvgTextRun>[];
    for (final chunk in chunks) {
      final shift = switch (chunk.anchor) {
        SvgTextAnchor.start => 0.0,
        SvgTextAnchor.middle => -chunk.width / 2,
        SvgTextAnchor.end => -chunk.width,
      };

      runs.addAll(
        shift == 0
            ? chunk.runs
            : chunk.runs.map((SvgTextRun run) => run.shifted(shift)),
      );
    }

    return SvgText(
      runs,
      _brush,
      SvgClipPath.fromXml(element, painter, _brush),
      SvgTransform.fromXml(element),
      painter,
    );
  }

  /// The elements whose content belongs to the text flow. Anything else - a
  /// `<desc>`, a `<title>`, a `<metadata>` - is not text and used to be drawn.
  static const _textContent = <String>{'tspan', 'textPath', 'a'};

  /// Walk [element] in document order, emitting a run per text node.
  static void _walk(
    XmlElement element,
    SvgPainter painter,
    SvgBrush brush,
    _Cursor cursor,
    List<_Chunk> chunks, {
    bool root = false,
  }) {
    final x = SvgParser.getNumeric(
      element,
      'x',
      brush,
    )?.sizeIn(painter.viewport, SvgAxis.horizontal);
    final y = SvgParser.getNumeric(
      element,
      'y',
      brush,
    )?.sizeIn(painter.viewport, SvgAxis.vertical);
    final dx = SvgParser.getNumeric(
      element,
      'dx',
      brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.horizontal);
    final dy = SvgParser.getNumeric(
      element,
      'dy',
      brush,
      defaultValue: 0,
    )!.sizeIn(painter.viewport, SvgAxis.vertical);

    // An absolute position starts a new chunk; dx and dy only move the cursor.
    if (root || x != null || y != null) {
      chunks.add(_Chunk(brush.textAnchor!));
    }
    cursor.move(x, y, dx, dy);

    final font = painter.getFontCache(
      brush.fontFamily!,
      brush.fontStyle!,
      brush.fontWeight!,
    )!;
    final pdfFont = font.getFont(Context(document: painter.document));
    final fontSize = brush.fontSize!.sizeValue;

    for (final node in element.children) {
      if (node is XmlText || node is XmlCDATA) {
        final text = _collapse(
          node.value ?? '',
          preserve: brush.preserveSpace ?? false,
          atChunkStart: chunks.last.runs.isEmpty,
        );
        if (text.isEmpty) {
          continue;
        }

        final metrics = pdfFont.stringMetrics(text) * fontSize;
        chunks.last.runs.add(
          SvgTextRun(text, cursor.x, cursor.y, pdfFont, metrics, brush),
        );
        cursor.advance(metrics.advanceWidth);
        continue;
      }

      if (node is XmlElement && _textContent.contains(node.name.local)) {
        _walk(
          node,
          painter,
          SvgBrush.fromXml(node, brush, painter),
          cursor,
          chunks,
        );
      }
    }
  }

  /// White space, per SVG 1.1 10.15.
  ///
  /// With the default handling a newline is removed, a tab becomes a space, runs
  /// of spaces collapse to one, and a leading space is dropped at the start of a
  /// chunk. A trailing space is kept, because it is what separates a run from the
  /// `<tspan>` after it - the old code trimmed each node and lost it.
  static String _collapse(
    String value, {
    required bool preserve,
    required bool atChunkStart,
  }) {
    if (preserve) {
      // Still never a literal newline or tab in a PDF string.
      return value.replaceAll(RegExp(r'[\r\n\t]'), ' ');
    }

    var text = value
        .replaceAll(RegExp(r'[\r\n]'), '')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r' +'), ' ');

    if (atChunkStart) {
      text = text.trimLeft();
    }

    return text;
  }

  /// The runs this element draws, in document order and already positioned.
  final List<SvgTextRun> runs;

  @override
  void paintShape(PdfGraphics canvas) {
    for (final run in runs) {
      _withRun(canvas, run, () {
        final brush = run.brush;

        // The colour may carry its own alpha, which the opacities multiply.
        final fillAlpha = brush.fillOpacity! * (brush.fill!.opacity ?? 1.0);
        final strokeAlpha =
            brush.strokeOpacity! * (brush.stroke!.opacity ?? 1.0);

        if (brush.fill!.isNotEmpty && fillAlpha > 0) {
          brush.fill!.setFillColor(this, canvas);
          if (fillAlpha < 1) {
            canvas
              ..saveContext()
              ..setGraphicState(PdfGraphicState(fillOpacity: fillAlpha));
          }
          canvas.drawString(
            run.font,
            brush.fontSize!.sizeValue,
            run.text,
            0,
            0,
          );
          if (fillAlpha < 1) {
            canvas.restoreContext();
          }
        }

        // See SvgPath.paintShape: a stroke-width of zero means no stroke at all.
        if (brush.hasStroke && strokeAlpha > 0) {
          if (brush.strokeWidth != null) {
            canvas.setLineWidth(
              brush.strokeWidth!.sizeIn(painter.viewport, SvgAxis.diagonal),
            );
          }
          if (brush.strokeDashArray != null) {
            canvas.setLineDashPattern(brush.strokeDashArray!);
          }
          if (strokeAlpha < 1) {
            canvas.setGraphicState(PdfGraphicState(strokeOpacity: strokeAlpha));
          }
          brush.stroke!.setStrokeColor(this, canvas);
          canvas.drawString(
            run.font,
            brush.fontSize!.sizeValue,
            run.text,
            0,
            0,
            mode: PdfTextRenderingMode.stroke,
          );
        }
      });
    }
  }

  @override
  void drawShape(PdfGraphics canvas) {
    for (final run in runs) {
      _withRun(canvas, run, () {
        canvas.drawString(
          run.font,
          run.brush.fontSize!.sizeValue,
          run.text,
          0,
          0,
          mode: PdfTextRenderingMode.clip,
        );
      });
    }
  }

  /// Put [run]'s own origin in force. The y axis is flipped by the root
  /// transform, so text has to be drawn the other way up.
  void _withRun(PdfGraphics canvas, SvgTextRun run, void Function() body) {
    canvas
      ..saveContext()
      ..setTransform(
        Matrix4.identity()
          ..scaleByDouble(1, -1, 1, 1)
          ..translateByDouble(run.x, -run.y, 0, 1),
      );
    body();
    canvas.restoreContext();
  }

  @override
  PdfRect boundingBox() {
    if (runs.isEmpty) {
      return PdfRect.zero;
    }

    var left = double.infinity,
        bottom = double.infinity,
        right = double.negativeInfinity,
        top = double.negativeInfinity;

    for (final run in runs) {
      final box = run.metrics.toPdfRect();
      left = min(left, run.x + box.left);
      bottom = min(bottom, run.y + box.bottom);
      right = max(right, run.x + box.right);
      top = max(top, run.y + box.top);
    }

    return PdfRect.fromLBRT(left, bottom, right, top);
  }
}

/// Where the next run starts.
class _Cursor {
  _Cursor(this.painter);

  final SvgPainter painter;

  double x = 0;

  double y = 0;

  void move(double? absoluteX, double? absoluteY, double dx, double dy) {
    x = (absoluteX ?? x) + dx;
    y = (absoluteY ?? y) + dy;
  }

  void advance(double width) {
    x += width;
  }
}
