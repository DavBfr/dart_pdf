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

part of widget;

enum TextAlign { left, right, center, justify }

abstract class _Span {
  _Span(this.style, this.annotation);

  final TextStyle style;

  final AnnotationBuilder annotation;

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

class _Word extends _Span {
  _Word(this.text, TextStyle style, this.metrics, AnnotationBuilder annotation)
      : super(style, annotation);

  final String text;

  final PdfFontMetrics metrics;

  @override
  double get left => metrics.left;

  @override
  double get top => metrics.top;

  @override
  double get width => metrics.width;

  @override
  double get height => metrics.height;

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
        point.y + offset.y);
  }

  @override
  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
  ) {
    const double deb = 5;

    context.canvas
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
  _WidgetSpan(this.widget, TextStyle style, AnnotationBuilder annotation)
      : assert(widget != null),
        assert(style != null),
        super(style, annotation);

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
}

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

  bool visitChildren(bool visitor(InlineSpan span, TextStyle parentStyle),
      TextStyle parentStyle);
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
  bool visitChildren(bool visitor(InlineSpan span, TextStyle parentStyle),
      TextStyle parentStyle) {
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
  bool visitChildren(bool visitor(InlineSpan span, TextStyle parentStyle),
      TextStyle parentStyle) {
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
      this.textScaleFactor = 1.0,
      this.maxLines})
      : assert(text != null);

  static bool debug = false;

  final InlineSpan text;

  final TextAlign textAlign;

  final double textScaleFactor;

  final bool softWrap;

  final int maxLines;

  final List<_Span> _spans = <_Span>[];

  double _realignLine(List<_Span> spans, double totalWidth, double wordsWidth,
      bool last, double baseline) {
    double delta = 0;
    switch (textAlign) {
      case TextAlign.left:
        totalWidth = wordsWidth;
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

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _spans.clear();

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
    int wCount = 0;
    int lineStart = 0;

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

            if (offsetX + metrics.width > constraintWidth && wCount > 0) {
              width = math.max(
                  width,
                  _realignLine(
                      _spans.sublist(lineStart),
                      constraintWidth,
                      offsetX - space.advanceWidth * style.wordSpacing,
                      false,
                      bottom));

              lineStart += wCount;

              if (maxLines != null && ++lines > maxLines) {
                break;
              }

              offsetX = 0.0;
              offsetY += bottom - top + style.lineSpacing;
              top = null;
              bottom = null;

              if (offsetY > constraintHeight) {
                return false;
              }
              wCount = 0;
            }

            final double baseline = span.baseline * textScaleFactor;
            top =
                math.min(top ?? metrics.top + baseline, metrics.top + baseline);
            bottom = math.max(
                bottom ?? metrics.bottom + baseline, metrics.bottom + baseline);

            final _Word wd = _Word(word, style, metrics, span.annotation);
            wd.offset = PdfPoint(offsetX, -offsetY + baseline);

            _spans.add(wd);
            wCount++;
            offsetX +=
                metrics.advanceWidth + space.advanceWidth * style.wordSpacing;
          }

          if (softWrap && line < spanLines.length - 1) {
            width = math.max(
                width,
                _realignLine(
                    _spans.sublist(lineStart),
                    constraintWidth,
                    offsetX - space.advanceWidth * style.wordSpacing,
                    false,
                    bottom));

            lineStart += wCount;

            if (maxLines != null && ++lines > maxLines) {
              break;
            }

            offsetX = 0.0;
            if (wCount > 0) {
              offsetY += bottom - top + style.lineSpacing;
            } else {
              offsetY += space.ascent + space.descent + style.lineSpacing;
            }
            top = null;
            bottom = null;

            if (offsetY > constraintHeight) {
              return false;
            }
            wCount = 0;
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
        final _WidgetSpan ws = _WidgetSpan(span.child, style, span.annotation);

        if (offsetX + ws.width > constraintWidth && wCount > 0) {
          width = math.max(
              width,
              _realignLine(_spans.sublist(lineStart), constraintWidth, offsetX,
                  false, bottom));

          lineStart += wCount;

          if (maxLines != null && ++lines > maxLines) {
            return false;
          }

          offsetX = 0.0;
          offsetY += bottom - top + style.lineSpacing;
          top = null;
          bottom = null;

          if (offsetY > constraintHeight) {
            return false;
          }
          wCount = 0;
        }

        final double baseline = span.baseline * textScaleFactor;
        top = math.min(top ?? baseline, baseline);
        bottom = math.max(bottom ?? ws.height + baseline, ws.height + baseline);

        ws.offset = PdfPoint(offsetX, -offsetY + baseline);
        _spans.add(ws);
        wCount++;
        offsetX += ws.left + ws.width;
      }

      return true;
    }, defaultstyle);

    width = math.max(
        width,
        _realignLine(
            _spans.sublist(lineStart), constraintWidth, offsetX, true, bottom));

    bottom ??= 0.0;
    top ??= 0.0;

    box = PdfRect(0, 0, constraints.constrainWidth(width),
        constraints.constrainHeight(offsetY + bottom - top));
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.blue)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    TextStyle currentStyle;
    PdfColor currentColor;

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

      if (span.annotation != null) {
        final PdfRect spanBox = PdfRect(box.x + span.offset.x + span.left,
            box.top + span.offset.y + span.top, span.width, span.height);
        span.annotation.build(context, spanBox);
      }

      span.paint(
        context,
        currentStyle,
        textScaleFactor,
        PdfPoint(box.left, box.top),
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
    double textScaleFactor = 1.0,
    int maxLines,
  })  : assert(text != null),
        super(
            text: TextSpan(text: text, style: style),
            textAlign: textAlign,
            softWrap: softWrap,
            textScaleFactor: textScaleFactor,
            maxLines: maxLines);
}
