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

@immutable
class TextStyle {
  const TextStyle({
    this.color = PdfColor.black,
    this.font,
    this.fontSize = _defaultFontSize,
    this.letterSpacing = 1.0,
    this.wordSpacing = 1.0,
    this.lineSpacing = 0.0,
    this.height = 1.0,
    this.background,
  })  : assert(font != null),
        assert(color != null);

  final PdfColor color;

  final PdfFont font;

  final double fontSize;

  static const double _defaultFontSize = 12.0 * PdfPageFormat.point;

  final double letterSpacing;

  final double lineSpacing;

  final double wordSpacing;

  final double height;

  final PdfColor background;

  TextStyle copyWith({
    PdfColor color,
    PdfFont font,
    double fontSize,
    double letterSpacing,
    double wordSpacing,
    double lineSpacing,
    double height,
    PdfColor background,
  }) {
    return TextStyle(
      color: color ?? this.color,
      font: font ?? this.font,
      fontSize: fontSize ?? this.fontSize,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      height: height ?? this.height,
      background: background ?? this.background,
    );
  }
}

enum TextAlign { left, right, center, justify }

class _Word {
  final String text;
  PdfRect _box;

  _Word(this.text, this._box);

  String toString() {
    return "Word $text $_box";
  }
}

class Text extends Widget {
  final String data;

  TextStyle style;

  final TextAlign textAlign;

  final double textScaleFactor;

  final int maxLines;

  Text(
    this.data, {
    this.style,
    this.textAlign = TextAlign.left,
    softWrap = true,
    this.textScaleFactor = 1.0,
    int maxLines,
  })  : maxLines = !softWrap ? 1 : maxLines,
        assert(data != null);

  final _words = List<_Word>();

  double _realignLine(
      List<_Word> words, double totalWidth, double wordsWidth, bool last) {
    var delta = 0.0;
    switch (textAlign) {
      case TextAlign.left:
        return wordsWidth;
      case TextAlign.right:
        delta = totalWidth - wordsWidth;
        break;
      case TextAlign.center:
        delta = (totalWidth - wordsWidth) / 2.0;
        break;
      case TextAlign.justify:
        if (last) return wordsWidth;
        delta = (totalWidth - wordsWidth) / (words.length - 1);
        var x = 0.0;
        for (var word in words) {
          word._box = PdfRect(
              word._box.x + x, word._box.y, word._box.width, word._box.height);
          x += delta;
        }
        return totalWidth;
    }
    for (var word in words) {
      word._box = PdfRect(
          word._box.x + delta, word._box.y, word._box.width, word._box.height);
    }
    return totalWidth;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {parentUsesSize = false}) {
    _words.clear();

    if (style == null) {
      style = Theme.of(context).defaultTextStyle;
    }

    final cw = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth();
    final ch = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight();

    var x = 0.0;
    var y = 0.0;
    var w = 0.0;
    var h = 0.0;
    var lh = 0.0;

    final space =
        style.font.stringBounds(" ") * (style.fontSize * textScaleFactor);

    var lines = 1;
    var wCount = 0;
    var lineStart = 0;

    for (var word in data.split(" ")) {
      final box =
          style.font.stringBounds(word) * (style.fontSize * textScaleFactor);

      var ww = box.width;
      var wh = box.height;

      if (x + ww > cw) {
        if (wCount == 0) break;
        w = math.max(
            w,
            _realignLine(
                _words.sublist(lineStart), cw, x - space.width, false));
        lineStart += wCount;
        if (maxLines != null && ++lines > maxLines) break;

        x = 0.0;
        y += lh + style.lineSpacing;
        h += lh + style.lineSpacing;
        lh = 0.0;
        if (y > ch) break;
        wCount = 0;
      }

      var wx = x;
      var wy = y;

      x += ww + space.width;
      lh = math.max(lh, wh);

      final wd = _Word(word, PdfRect(box.x + wx, box.y + wy + wh, ww, wh));
      _words.add(wd);
      wCount++;
    }
    w = math.max(
        w, _realignLine(_words.sublist(lineStart), cw, x - space.width, true));
    h += lh;
    box = PdfRect(0.0, 0.0, constraints.constrainWidth(w),
        constraints.constrainHeight(h));
  }

  @protected
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColor.blue)
      ..drawRect(box.x, box.y, box.width, box.height)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    context.canvas.setFillColor(style.color);

    for (var word in _words) {
      context.canvas.drawString(style.font, style.fontSize * textScaleFactor,
          word.text, box.x + word._box.x, box.y + box.height - word._box.y);
    }
  }
}
