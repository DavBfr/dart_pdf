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

class _Word {
  _Word(this.text, this.style, this.metrics, this.annotation);

  final String text;

  final TextStyle style;

  final PdfFontMetrics metrics;

  PdfPoint offset = PdfPoint.zero;

  final AnnotationBuilder annotation;

  @override
  String toString() {
    return 'Word "$text" offset:$offset metrics:$metrics style:$style';
  }

  void debugPaint(Context context, double textScaleFactor, PdfRect globalBox) {
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

class TextSpan {
  const TextSpan({this.style, this.text, this.children, this.annotation});

  final TextStyle style;

  final String text;

  final List<TextSpan> children;

  final AnnotationBuilder annotation;

  String toPlainText() {
    final StringBuffer buffer = StringBuffer();
    visitTextSpan((TextSpan span, TextStyle style) {
      buffer.write(span.text);
      return true;
    }, null);
    return buffer.toString();
  }

  bool visitTextSpan(bool visitor(TextSpan span, TextStyle parentStyle),
      TextStyle parentStyle) {
    final TextStyle _style = parentStyle?.merge(style);

    if (text != null) {
      if (!visitor(this, _style)) {
        return false;
      }
    }
    if (children != null) {
      for (TextSpan child in children) {
        if (!child.visitTextSpan(visitor, _style)) {
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
      bool softWrap = true,
      this.textScaleFactor = 1.0,
      int maxLines})
      : maxLines = !softWrap ? 1 : maxLines,
        assert(text != null);

  static const bool debug = false;

  final TextSpan text;

  final TextAlign textAlign;

  final double textScaleFactor;

  final int maxLines;

  final List<_Word> _words = <_Word>[];

  double _realignLine(List<_Word> words, double totalWidth, double wordsWidth,
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
        delta = (totalWidth - wordsWidth) / (words.length - 1);
        double x = 0;
        for (_Word word in words) {
          word.offset = word.offset.translate(x, -baseline);
          x += delta;
        }
        return totalWidth;
    }

    for (_Word word in words) {
      word.offset = word.offset.translate(delta, -baseline);
    }
    return totalWidth;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _words.clear();

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

    text.visitTextSpan((TextSpan span, TextStyle style) {
      if (span.text == null) {
        return true;
      }

      final PdfFont font = style.paintFont.getFont(context);

      final PdfFontMetrics space =
          font.stringMetrics(' ') * (style.fontSize * textScaleFactor);

      for (String word in span.text.split(RegExp(r'\s'))) {
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
                  _words.sublist(lineStart),
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

        top = math.min(top ?? metrics.top, metrics.top);
        bottom = math.max(bottom ?? metrics.bottom, metrics.bottom);

        final _Word wd = _Word(word, style, metrics, span.annotation);
        wd.offset = PdfPoint(offsetX, -offsetY);

        _words.add(wd);
        wCount++;
        offsetX +=
            metrics.advanceWidth + space.advanceWidth * style.wordSpacing;
      }

      offsetX -= space.advanceWidth * style.wordSpacing;
      return true;
    }, defaultstyle);

    width = math.max(
        width,
        _realignLine(
            _words.sublist(lineStart), constraintWidth, offsetX, true, bottom));

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

    for (_Word word in _words) {
      assert(() {
        if (Document.debug && RichText.debug) {
          word.debugPaint(context, textScaleFactor, box);
        }
        return true;
      }());

      if (word.style != currentStyle) {
        currentStyle = word.style;
        if (currentStyle.color != currentColor) {
          currentColor = currentStyle.color;
          context.canvas.setFillColor(currentColor);
        }
      }

      if (word.annotation != null) {
        final PdfRect wordBox = PdfRect(
            box.x + word.offset.x + word.metrics.left,
            box.top + word.offset.y + word.metrics.top,
            word.metrics.width,
            word.metrics.height);
        word.annotation.build(context, wordBox);
      }

      context.canvas.drawString(
          currentStyle.paintFont.getFont(context),
          currentStyle.fontSize * textScaleFactor,
          word.text,
          box.x + word.offset.x,
          box.top + word.offset.y);
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
