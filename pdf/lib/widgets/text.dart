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

// ignore_for_file: omit_local_variable_types

part of widget;

enum TextAlign { left, right, center, justify }

abstract class _Span {
  _Span(this.style);

  final TextStyle style;

  PdfPoint offset = PdfPoint.zero;

  double left;
  double top;
  double width;
  double height;

  @override
  String toString() {
    return 'Span "offset:$offset';
  }

  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
  ) {}

  void paint(
    Context context,
    TextStyle style,
    double textScaleFactor,
    PdfPoint point,
  );
}

class _TextDecoration {
  _TextDecoration(this.style, this.annotation, this.startSpan, this.endSpan)
      : assert(startSpan <= endSpan),
        assert(style != null);

  static const double _space = -0.15;

  final TextStyle style;

  final AnnotationBuilder annotation;

  final int startSpan;

  final int endSpan;

  PdfRect _box;

  PdfRect _getBox(List<_Span> spans) {
    if (_box != null) {
      return _box;
    }
    final double x1 = spans[startSpan].offset.x + spans[startSpan].left;
    final double x2 =
        spans[endSpan].offset.x + spans[endSpan].left + spans[endSpan].width;
    double y1 = spans[startSpan].offset.y + spans[startSpan].top;
    double y2 = y1 + spans[startSpan].height;

    for (int n = startSpan + 1; n <= endSpan; n++) {
      final double ny1 = spans[n].offset.y + spans[n].top;
      final double ny2 = ny1 + spans[n].height;
      y1 = math.min(y1, ny1);
      y2 = math.max(y2, ny2);
    }

    _box = PdfRect.fromLTRB(x1, y1, x2, y2);
    return _box;
  }

  _TextDecoration copyWith({int endSpan}) =>
      _TextDecoration(style, annotation, startSpan, endSpan ?? this.endSpan);

  void backgroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
    List<_Span> spans,
  ) {
    final PdfRect box = _getBox(spans);

    if (annotation != null) {
      final PdfRect spanBox = PdfRect(
        globalBox.x + box.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      annotation.build(context, spanBox);
    }

    if (style.background != null) {
      final PdfRect boundingBox = PdfRect(
        globalBox.x + box.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      style.background.paint(context, boundingBox);
      context.canvas.setFillColor(style.color);
    }
  }

  void foregroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
    List<_Span> spans,
  ) {
    if (style.decoration == null) {
      return;
    }

    final PdfRect box = _getBox(spans);

    final PdfFont font = style.font.getFont(context);
    final double space =
        _space * style.fontSize * textScaleFactor * style.decorationThickness;

    context.canvas
      ..setStrokeColor(style.decorationColor ?? style.color)
      ..setLineWidth(
          style.decorationThickness * style.fontSize * textScaleFactor * 0.05);

    if (style.decoration.contains(TextDecoration.underline)) {
      final double base = -font.descent * style.fontSize * textScaleFactor / 2;

      context.canvas.drawLine(
        globalBox.x + box.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base + space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration.contains(TextDecoration.overline)) {
      final double base = style.fontSize * textScaleFactor;
      context.canvas.drawLine(
        globalBox.x + box.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base - space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base - space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration.contains(TextDecoration.lineThrough)) {
      final double base =
          (1 - font.descent) * style.fontSize * textScaleFactor / 2;
      context.canvas.drawLine(
        globalBox.x + box.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base + space,
        );
      }
      context.canvas.strokePath();
    }
  }

  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
    List<_Span> spans,
  ) {
    final PdfRect box = _getBox(spans);

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
          globalBox.x + box.x, globalBox.top + box.y, box.width, box.height)
      ..setStrokeColor(PdfColors.yellow)
      ..strokePath();
  }
}

class _Word extends _Span {
  _Word(
    this.text,
    TextStyle style,
    this.metrics,
  ) : super(style);

  final String text;

  final PdfFontMetrics metrics;

  @override
  double get left => metrics.left;

  @override
  double get top => metrics.descent;

  @override
  double get width => metrics.width;

  @override
  double get height => metrics.maxHeight;

  @override
  String toString() {
    return 'Word "$text" offset:$offset metrics:$metrics style:$style';
  }

  @override
  void paint(
    Context context,
    TextStyle style,
    double textScaleFactor,
    PdfPoint point,
  ) {
    context.canvas.drawString(
      style.font.getFont(context),
      style.fontSize * textScaleFactor,
      text,
      point.x + offset.x,
      point.y + offset.y,
      mode: style.renderingMode,
    );
  }

  @override
  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
  ) {
    const double deb = 5;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(globalBox.x + offset.x + metrics.left,
          globalBox.top + offset.y + metrics.top, metrics.width, metrics.height)
      ..setStrokeColor(PdfColors.orange)
      ..strokePath()
      ..drawLine(
          globalBox.x + offset.x - deb,
          globalBox.top + offset.y,
          globalBox.x + offset.x + metrics.right + deb,
          globalBox.top + offset.y)
      ..setStrokeColor(PdfColors.deepPurple)
      ..strokePath();
  }
}

class _WidgetSpan extends _Span {
  _WidgetSpan(this.widget, TextStyle style)
      : assert(widget != null),
        assert(style != null),
        super(style);

  final Widget widget;

  @override
  double get left => 0;

  @override
  double get top => 0;

  @override
  double get width => widget.box.width;

  @override
  double get height => widget.box.height;

  @override
  PdfPoint get offset => widget.box.offset;

  @override
  set offset(PdfPoint value) {
    widget.box = PdfRect.fromPoints(value, widget.box.size);
  }

  @override
  String toString() {
    return 'Widget "$widget" offset:$offset';
  }

  @override
  void paint(
    Context context,
    TextStyle style,
    double textScaleFactor,
    PdfPoint point,
  ) {
    widget.box = PdfRect.fromPoints(
        PdfPoint(point.x + widget.box.offset.x, point.y + widget.box.offset.y),
        widget.box.size);
    widget.paint(context);
  }

  @override
  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
  ) {
    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
          globalBox.x + offset.x, globalBox.top + offset.y, width, height)
      ..setStrokeColor(PdfColors.orange)
      ..strokePath();
  }
}

typedef _VisitorCallback = bool Function(
    InlineSpan span, TextStyle parentStyle);

@immutable
abstract class InlineSpan {
  const InlineSpan({this.style, this.baseline, this.annotation});

  final TextStyle style;

  final double baseline;

  final AnnotationBuilder annotation;

  String toPlainText() {
    final StringBuffer buffer = StringBuffer();
    visitChildren((InlineSpan span, TextStyle style) {
      if (span is TextSpan) {
        buffer.write(span.text);
      }
      return true;
    }, null);
    return buffer.toString();
  }

  bool visitChildren(_VisitorCallback visitor, TextStyle parentStyle);
}

class WidgetSpan extends InlineSpan {
  /// Creates a [WidgetSpan] with the given values.
  const WidgetSpan({
    @required this.child,
    double baseline = 0,
    TextStyle style,
    AnnotationBuilder annotation,
  })  : assert(child != null),
        super(style: style, baseline: baseline, annotation: annotation);

  /// The widget to embed inline within text.
  final Widget child;

  /// Calls `visitor` on this [WidgetSpan]. There are no children spans to walk.
  @override
  bool visitChildren(_VisitorCallback visitor, TextStyle parentStyle) {
    final TextStyle _style = parentStyle?.merge(style);

    if (child != null) {
      if (!visitor(this, _style)) {
        return false;
      }
    }

    return true;
  }
}

class TextSpan extends InlineSpan {
  const TextSpan({
    TextStyle style,
    this.text,
    double baseline = 0,
    this.children,
    AnnotationBuilder annotation,
  }) : super(style: style, baseline: baseline, annotation: annotation);

  final String text;

  final List<InlineSpan> children;

  @override
  bool visitChildren(_VisitorCallback visitor, TextStyle parentStyle) {
    final TextStyle _style = parentStyle?.merge(style);

    if (text != null) {
      if (!visitor(this, _style)) {
        return false;
      }
    }
    if (children != null) {
      for (InlineSpan child in children) {
        if (!child.visitChildren(visitor, _style)) {
          return false;
        }
      }
    }
    return true;
  }
}

class RichText extends Widget {
  RichText(
      {@required this.text,
      this.textAlign = TextAlign.left,
      this.softWrap = true,
      this.tightBounds = false,
      this.textScaleFactor = 1.0,
      this.maxLines})
      : assert(text != null);

  static bool debug = false;

  final InlineSpan text;

  final TextAlign textAlign;

  final double textScaleFactor;

  final bool softWrap;

  final bool tightBounds;

  final int maxLines;

  final List<_Span> _spans = <_Span>[];

  final List<_TextDecoration> _decorations = <_TextDecoration>[];

  double _realignLine(
    List<_Span> spans,
    List<_TextDecoration> decorations,
    double totalWidth,
    double wordsWidth,
    bool last,
    double baseline,
  ) {
    double delta = 0;
    switch (textAlign) {
      case TextAlign.left:
        break;
      case TextAlign.right:
        delta = totalWidth - wordsWidth;
        break;
      case TextAlign.center:
        delta = (totalWidth - wordsWidth) / 2.0;
        break;
      case TextAlign.justify:
        if (last) {
          totalWidth = wordsWidth;
          break;
        }
        delta = (totalWidth - wordsWidth) / (spans.length - 1);
        double x = 0;
        for (_Span span in spans) {
          span.offset = span.offset.translate(x, -baseline);
          x += delta;
        }
        return totalWidth;
    }

    for (_Span span in spans) {
      span.offset = span.offset.translate(delta, -baseline);
    }

    return totalWidth;
  }

  void _appendDecoration(bool append, _TextDecoration td) {
    if (append && _decorations.isNotEmpty) {
      final _TextDecoration last = _decorations.last;
      if (last.style == td.style && last.annotation == td.annotation) {
        _decorations[_decorations.length - 1] =
            last.copyWith(endSpan: td.endSpan);
        return;
      }
    }

    _decorations.add(td);
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _spans.clear();
    _decorations.clear();

    final TextStyle defaultstyle = Theme.of(context).defaultTextStyle;

    final double constraintWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth();
    final double constraintHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight();

    double offsetX = 0;
    double offsetY = 0;
    double width = 0;
    double top;
    double bottom;

    int lines = 1;
    int spanCount = 0;
    int spanStart = 0;
    int decorationStart = 0;

    text.visitChildren((InlineSpan span, TextStyle style) {
      if (span is TextSpan) {
        if (span.text == null) {
          return true;
        }

        final PdfFont font = style.font.getFont(context);

        final PdfFontMetrics space =
            font.stringMetrics(' ') * (style.fontSize * textScaleFactor);

        final List<String> spanLines = span.text.split('\n');
        for (int line = 0; line < spanLines.length; line++) {
          for (String word in spanLines[line].split(RegExp(r'\s'))) {
            if (word.isEmpty) {
              offsetX += space.advanceWidth * style.wordSpacing;
              continue;
            }

            final PdfFontMetrics metrics =
                font.stringMetrics(word) * (style.fontSize * textScaleFactor);

            if (offsetX + metrics.width > constraintWidth && spanCount > 0) {
              width = math.max(
                  width,
                  _realignLine(
                    _spans.sublist(spanStart),
                    _decorations.sublist(decorationStart),
                    constraintWidth,
                    offsetX - space.advanceWidth * style.wordSpacing,
                    false,
                    bottom,
                  ));

              spanStart += spanCount;
              decorationStart = _decorations.length;

              lines++;
              if (maxLines != null && lines > maxLines) {
                break;
              }

              offsetX = 0.0;
              offsetY += bottom - top + style.lineSpacing;
              top = null;
              bottom = null;

              if (offsetY > constraintHeight) {
                return false;
              }
              spanCount = 0;
            }

            final double baseline = span.baseline * textScaleFactor;
            final double mt = tightBounds ? metrics.top : metrics.descent;
            final double mb = tightBounds ? metrics.bottom : metrics.ascent;
            top = math.min(top ?? mt + baseline, mt + baseline);
            bottom = math.max(bottom ?? mb + baseline, mb + baseline);

            final _Word wd = _Word(
              word,
              style,
              metrics,
            );
            wd.offset = PdfPoint(offsetX, -offsetY + baseline);
            _spans.add(wd);
            spanCount++;

            _appendDecoration(
              spanCount > 1,
              _TextDecoration(
                style,
                span.annotation,
                _spans.length - 1,
                _spans.length - 1,
              ),
            );

            offsetX +=
                metrics.advanceWidth + space.advanceWidth * style.wordSpacing;
          }

          if (softWrap && line < spanLines.length - 1) {
            width = math.max(
                width,
                _realignLine(
                  _spans.sublist(spanStart),
                  _decorations.sublist(decorationStart),
                  constraintWidth,
                  offsetX - space.advanceWidth * style.wordSpacing,
                  false,
                  bottom,
                ));

            spanStart += spanCount;
            decorationStart = _decorations.length;

            lines++;
            if (maxLines != null && lines > maxLines) {
              break;
            }

            offsetX = 0.0;
            if (spanCount > 0) {
              offsetY += bottom - top + style.lineSpacing;
            } else {
              offsetY += space.ascent + space.descent + style.lineSpacing;
            }
            top = null;
            bottom = null;

            if (offsetY > constraintHeight) {
              return false;
            }
            spanCount = 0;
          }
        }

        offsetX -= space.advanceWidth * style.wordSpacing;
      } else if (span is WidgetSpan) {
        span.child.layout(
            context,
            BoxConstraints.tight(PdfPoint(
              double.infinity,
              style.fontSize * textScaleFactor,
            )));
        final _WidgetSpan ws = _WidgetSpan(
          span.child,
          style,
        );

        if (offsetX + ws.width > constraintWidth && spanCount > 0) {
          width = math.max(
              width,
              _realignLine(
                _spans.sublist(spanStart),
                _decorations.sublist(decorationStart),
                constraintWidth,
                offsetX,
                false,
                bottom,
              ));

          spanStart += spanCount;
          decorationStart = _decorations.length;

          lines++;
          if (maxLines != null && lines > maxLines) {
            return false;
          }

          offsetX = 0.0;
          offsetY += bottom - top + style.lineSpacing;
          top = null;
          bottom = null;

          if (offsetY > constraintHeight) {
            return false;
          }
          spanCount = 0;
        }

        final double baseline = span.baseline * textScaleFactor;
        top = math.min(top ?? baseline, baseline);
        bottom = math.max(
          bottom ?? ws.height + baseline,
          ws.height + baseline,
        );

        ws.offset = PdfPoint(offsetX, -offsetY + baseline);
        _spans.add(ws);
        spanCount++;

        _appendDecoration(
          spanCount > 1,
          _TextDecoration(
            style,
            span.annotation,
            _spans.length - 1,
            _spans.length - 1,
          ),
        );

        offsetX += ws.left + ws.width;
      }

      return true;
    }, defaultstyle);

    width = math.max(
        width,
        _realignLine(
          _spans.sublist(spanStart),
          _decorations.sublist(decorationStart),
          lines > 1 ? constraintWidth : offsetX,
          offsetX,
          true,
          bottom,
        ));

    bottom ??= 0.0;
    top ??= 0.0;

    box = PdfRect(0, 0, constraints.constrainWidth(width),
        constraints.constrainHeight(offsetY + bottom - top));
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.blue)
      ..setLineWidth(1)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    TextStyle currentStyle;
    PdfColor currentColor;

    for (_TextDecoration decoration in _decorations) {
      assert(() {
        if (Document.debug && RichText.debug) {
          decoration.debugPaint(context, textScaleFactor, box, _spans);
        }
        return true;
      }());

      decoration.backgroundPaint(
        context,
        textScaleFactor,
        box,
        _spans,
      );
    }

    for (_Span span in _spans) {
      assert(() {
        if (Document.debug && RichText.debug) {
          span.debugPaint(context, textScaleFactor, box);
        }
        return true;
      }());

      if (span.style != currentStyle) {
        currentStyle = span.style;
        if (currentStyle.color != currentColor) {
          currentColor = currentStyle.color;
          context.canvas.setFillColor(currentColor);
        }
      }

      span.paint(
        context,
        currentStyle,
        textScaleFactor,
        PdfPoint(box.left, box.top),
      );
    }

    for (_TextDecoration decoration in _decorations) {
      decoration.foregroundPaint(
        context,
        textScaleFactor,
        box,
        _spans,
      );
    }
  }
}

class Text extends RichText {
  Text(
    String text, {
    TextStyle style,
    TextAlign textAlign = TextAlign.left,
    bool softWrap = true,
    bool tightBounds = false,
    double textScaleFactor = 1.0,
    int maxLines,
  })  : assert(text != null),
        super(
            text: TextSpan(text: text, style: style),
            textAlign: textAlign,
            softWrap: softWrap,
            tightBounds: tightBounds,
            textScaleFactor: textScaleFactor,
            maxLines: maxLines);
}
