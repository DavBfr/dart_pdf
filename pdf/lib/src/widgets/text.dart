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

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../pdf.dart';
import '../pdf/font/arabic.dart' as arabic;
import '../pdf/font/bidi_utils.dart' as bidi;
import '../pdf/options.dart';
import 'annotations.dart';
import 'basic.dart';
import 'document.dart';
import 'font.dart';
import 'geometry.dart';
import 'image.dart';
import 'image_provider.dart';
import 'multi_page.dart';
import 'placeholders.dart';
import 'text_segmentation.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

enum TextAlign { left, right, start, end, center, justify }

enum TextDirection { ltr, rtl }

/// How overflowing text should be handled.
enum TextOverflow {
  /// Clip the overflowing text to fix its container.
  clip,

  /// Render overflowing text outside of its container.
  visible,

  /// Span to the next page when possible.
  span,
}

abstract class _Span {
  _Span(this.style);

  final TextStyle style;

  var offset = PdfPoint.zero;

  double get left;

  double get top;

  double get width;

  double get height;

  @override
  String toString() {
    return 'Span "offset:$offset';
  }

  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
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
    : assert(startSpan <= endSpan);

  static const double _space = -0.15;

  final TextStyle style;

  final AnnotationBuilder? annotation;

  final int startSpan;

  final int endSpan;

  PdfRect? _box;

  PdfRect? _getBox(List<_Span> spans) {
    if (_box != null) {
      return _box;
    }

    // The extremes over the whole range, not the first and last span: a line is
    // reordered into visual order after it is built, so the first span of a
    // decoration is not necessarily its leftmost.
    var x1 = spans[startSpan].offset.x + spans[startSpan].left;
    var x2 = x1 + spans[startSpan].width;
    var y1 = spans[startSpan].offset.y + spans[startSpan].top;
    var y2 = y1 + spans[startSpan].height;

    for (var n = startSpan + 1; n <= endSpan; n++) {
      final nx1 = spans[n].offset.x + spans[n].left;
      x1 = math.min(x1, nx1);
      x2 = math.max(x2, nx1 + spans[n].width);
      final ny1 = spans[n].offset.y + spans[n].top;
      final ny2 = ny1 + spans[n].height;
      y1 = math.min(y1, ny1);
      y2 = math.max(y2, ny2);
    }

    _box = PdfRect.fromLBRT(x1, y1, x2, y2);
    return _box;
  }

  _TextDecoration copyWith({int? endSpan}) =>
      _TextDecoration(style, annotation, startSpan, endSpan ?? this.endSpan);

  void backgroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
    List<_Span> spans,
  ) {
    final box = _getBox(spans);

    if (annotation != null) {
      final spanBox = PdfRect(
        globalBox!.left + box!.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      annotation!.build(context, spanBox);
    }

    if (style.background != null) {
      final boundingBox = PdfRect(
        globalBox!.left + box!.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      style.background!.paint(context, boundingBox);
      context.canvas.setFillColor(style.color);
    }
  }

  void foregroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
    List<_Span> spans,
  ) {
    if (style.decoration == null) {
      return;
    }

    final box = _getBox(spans);

    final font = style.font!.getFont(context);
    final space =
        _space * style.fontSize! * textScaleFactor * style.decorationThickness!;

    context.canvas
      ..setStrokeColor(style.decorationColor ?? style.color)
      ..setLineWidth(
        style.decorationThickness! * style.fontSize! * textScaleFactor * 0.05,
      );

    if (style.decoration!.contains(TextDecoration.underline)) {
      final base = -font.descent * style.fontSize! * textScaleFactor / 2;
      final l = box!.left;
      final r = box.right;
      final x = globalBox!.left;
      context.canvas.drawLine(
        x + l,
        globalBox.top + box.bottom + base,
        x + r,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.left + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.left + box.right,
          globalBox.top + box.bottom + base + space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration!.contains(TextDecoration.overline)) {
      final base = style.fontSize! * textScaleFactor;
      context.canvas.drawLine(
        globalBox!.left + box!.left,
        globalBox.top + box.bottom + base,
        globalBox.left + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.left + box.left,
          globalBox.top + box.bottom + base - space,
          globalBox.left + box.right,
          globalBox.top + box.bottom + base - space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration!.contains(TextDecoration.lineThrough)) {
      final base = (1 - font.descent) * style.fontSize! * textScaleFactor / 2;
      context.canvas.drawLine(
        globalBox!.left + box!.left,
        globalBox.top + box.bottom + base,
        globalBox.left + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.left + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.left + box.right,
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
    final box = _getBox(spans)!;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
        globalBox.left + box.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      )
      ..setStrokeColor(PdfColors.yellow)
      ..strokePath();
  }
}

class _Word extends _Span {
  _Word(this.text, TextStyle style, this.metrics) : super(style);

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
      style.font!.getFont(context),
      style.fontSize! * textScaleFactor,
      text,
      point.x + offset.x,
      point.y + offset.y,
      mode: style.renderingMode ?? PdfTextRenderingMode.fill,
      charSpace: style.letterSpacing ?? 0,
    );
  }

  @override
  void debugPaint(Context context, double textScaleFactor, PdfRect? globalBox) {
    const deb = 5;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
        globalBox!.left + offset.x + metrics.left,
        globalBox.top + offset.y + metrics.top,
        metrics.width,
        metrics.height,
      )
      ..setStrokeColor(PdfColors.orange)
      ..strokePath()
      ..drawLine(
        globalBox.left + offset.x - deb,
        globalBox.top + offset.y,
        globalBox.left + offset.x + metrics.right + deb,
        globalBox.top + offset.y,
      )
      ..setStrokeColor(PdfColors.deepPurple)
      ..strokePath();
  }
}

class _WidgetSpan extends _Span {
  _WidgetSpan(this.widget, TextStyle style, this.baseline) : super(style);

  final Widget widget;

  final double baseline;

  @override
  double get left => 0;

  @override
  double get top => 0;

  @override
  double get width => widget.box!.width;

  @override
  double get height => widget.box!.height;

  @override
  PdfPoint get offset => widget.box!.offset;

  @override
  set offset(PdfPoint value) {
    widget.box = PdfRect.fromPoints(value, widget.box!.size);
  }

  @override
  String toString() {
    return 'Widget "$widget" offset:$offset';
  }

  @override
  void paint(
    Context context,
    TextStyle? style,
    double textScaleFactor,
    PdfPoint point,
  ) {
    widget.box = PdfRect.fromPoints(
      PdfPoint(point.x + widget.box!.offset.x, point.y + widget.box!.offset.y),
      widget.box!.size,
    );
    widget.paint(context);
  }

  @override
  void debugPaint(Context context, double textScaleFactor, PdfRect? globalBox) {
    const deb = 5;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
        globalBox!.left + offset.x,
        globalBox.top + offset.y,
        width,
        height,
      )
      ..setStrokeColor(PdfColors.orange)
      ..strokePath()
      ..drawLine(
        globalBox.left + offset.x - deb,
        globalBox.top + offset.y - baseline,
        globalBox.left + offset.x + width + deb,
        globalBox.top + offset.y - baseline,
      )
      ..setStrokeColor(PdfColors.deepPurple)
      ..strokePath();
  }
}

typedef VisitorCallback =
    bool Function(
      InlineSpan span,
      TextStyle? parentStyle,
      AnnotationBuilder? annotation,
    );

@immutable
abstract class InlineSpan {
  const InlineSpan({this.style, required this.baseline, this.annotation});

  final TextStyle? style;

  final double baseline;

  final AnnotationBuilder? annotation;

  InlineSpan copyWith({
    TextStyle? style,
    double? baseline,
    AnnotationBuilder? annotation,
  });

  String toPlainText() {
    final buffer = StringBuffer();
    visitChildren(
      (InlineSpan span, TextStyle? style, AnnotationBuilder? annotation) {
        if (span is TextSpan) {
          buffer.write(span.text);
        }
        return true;
      },
      null,
      null,
    );
    return buffer.toString();
  }

  bool visitChildren(
    VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  );
}

class WidgetSpan extends InlineSpan {
  /// Creates a [WidgetSpan] with the given values.
  const WidgetSpan({
    required this.child,
    double baseline = 0,
    TextStyle? style,
    AnnotationBuilder? annotation,
  }) : super(style: style, baseline: baseline, annotation: annotation);

  /// The widget to embed inline within text.
  final Widget child;

  @override
  InlineSpan copyWith({
    TextStyle? style,
    double? baseline,
    AnnotationBuilder? annotation,
  }) => WidgetSpan(
    child: child,
    style: style ?? this.style,
    baseline: baseline ?? this.baseline,
    annotation: annotation ?? this.annotation,
  );

  /// Calls `visitor` on this [WidgetSpan]. There are no children spans to walk.
  @override
  bool visitChildren(
    VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  ) {
    final _style = parentStyle?.merge(style);
    final _a = this.annotation ?? annotation;

    return visitor(this, _style, _a);
  }
}

class TextSpan extends InlineSpan {
  const TextSpan({
    TextStyle? style,
    this.text,
    double baseline = 0,
    this.children,
    AnnotationBuilder? annotation,
  }) : super(style: style, baseline: baseline, annotation: annotation);

  final String? text;

  final List<InlineSpan>? children;

  @override
  InlineSpan copyWith({
    TextStyle? style,
    double? baseline,
    AnnotationBuilder? annotation,
  }) => TextSpan(
    style: style ?? this.style,
    text: text,
    baseline: baseline ?? this.baseline,
    children: children,
    annotation: annotation ?? this.annotation,
  );

  @override
  bool visitChildren(
    VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  ) {
    final _style = parentStyle?.merge(style);
    final _annotation = this.annotation ?? annotation;

    if (text != null) {
      if (!visitor(this, _style, _annotation)) {
        return false;
      }
    }
    if (children != null) {
      for (final child in children!) {
        if (!child.visitChildren(visitor, _style, _annotation)) {
          return false;
        }
      }
    }
    return true;
  }
}

class _Line {
  const _Line(
    this.parent,
    this.firstSpan,
    this.countSpan,
    this.baseline,
    this.wordsWidth,
    this.textDirection,
    this.justify,
  );

  final RichText parent;

  final int firstSpan;
  final int countSpan;

  int get lastSpan => firstSpan + countSpan;

  TextAlign get textAlign => parent._textAlign;

  final double baseline;

  final double wordsWidth;

  final TextDirection textDirection;

  final bool justify;

  double get height {
    final list = parent._spans.sublist(firstSpan, lastSpan);
    return list.isEmpty
        ? 0
        : list.reduce((a, b) => a.height > b.height ? a : b).height;
  }

  @override
  String toString() =>
      '$runtimeType $firstSpan-$lastSpan baseline: $baseline width:$wordsWidth';

  void realign(double totalWidth) {
    final spans = parent._spans.sublist(firstSpan, lastSpan);
    final isRTL = textDirection == TextDirection.rtl;

    // The bidi algorithm has already put this line in visual order, so all that
    // is left is a uniform shift. Only the legacy arabic.convert path, which
    // shapes without reordering, still needs the line mirrored here.
    final mirror = !useBidi && isRTL;

    var delta = 0.0;
    switch (textAlign) {
      case TextAlign.left:
        delta = mirror ? wordsWidth : 0;
        break;
      case TextAlign.right:
        delta = mirror ? totalWidth : totalWidth - wordsWidth;
        break;
      case TextAlign.start:
        delta = mirror ? totalWidth : (isRTL ? totalWidth - wordsWidth : 0);
        break;
      case TextAlign.end:
        delta = mirror ? wordsWidth : (isRTL ? 0 : totalWidth - wordsWidth);
        break;
      case TextAlign.center:
        delta = (totalWidth - wordsWidth) / 2.0;
        if (mirror) {
          delta += wordsWidth;
        }
        break;
      case TextAlign.justify:
        delta = mirror ? totalWidth : (isRTL ? totalWidth - wordsWidth : 0);
        if (!justify) {
          break;
        }

        final gap = (totalWidth - wordsWidth) / (spans.length - 1);
        var x = 0.0;

        if (mirror) {
          for (final span in spans) {
            span.offset = PdfPoint(
              delta - x - (span.offset.x + span.width),
              span.offset.y - baseline,
            );
            x += gap;
          }

          return;
        }

        // Widen the gaps the line already has, which means walking it as it is
        // drawn rather than as it was built.
        for (final span
            in spans.toList()
              ..sort((_Span a, _Span b) => a.offset.x.compareTo(b.offset.x))) {
          span.offset = PdfPoint(span.offset.x + x, span.offset.y - baseline);
          x += gap;
        }

        return;
    }

    if (mirror) {
      for (final span in spans) {
        span.offset = PdfPoint(
          delta - (span.offset.x + span.width),
          span.offset.y - baseline,
        );
      }
      return;
    }

    for (final span in spans) {
      span.offset = span.offset.translate(delta, -baseline);
    }
  }
}

class RichTextContext extends WidgetContext {
  var startOffset = 0.0;
  var endOffset = 0.0;
  var spanStart = 0;
  var spanEnd = 0;

  @override
  void apply(RichTextContext other) {
    startOffset = other.startOffset;
    endOffset = other.endOffset;
    spanStart = other.spanStart;
    spanEnd = other.spanEnd;
  }

  @override
  WidgetContext clone() {
    return RichTextContext()..apply(this);
  }

  @override
  bool isSameAs(RichTextContext other) =>
      spanStart == other.spanStart &&
      spanEnd == other.spanEnd &&
      startOffset == other.startOffset &&
      endOffset == other.endOffset;

  @override
  String toString() =>
      '$runtimeType Offset: $startOffset -> $endOffset  Span: $spanStart -> $spanEnd';
}

typedef Hyphenation = List<String> Function(String word);

/// Signature of a function that splits a line of text into words that may be
/// wrapped independently.
///
/// By default, lines are split at whitespace, which means that scripts without
/// word separators (Chinese, Japanese, Korean...) are treated as a single
/// word and can only be broken by the hard-splitting fallback, without any
/// line breaking rule (no prohibition of closing punctuation at the beginning
/// of a line, etc.).
///
/// Providing a custom splitter enables script-aware line wrapping, for
/// instance breaking between CJK characters, or implementing the Unicode Line
/// Breaking Algorithm (UAX #14):
///
/// ```dart
/// RichText(
///   text: TextSpan(
///     text: '你好，世界',
///     // Each CJK character may wrap independently. Spaces are not inserted
///     // between the words, so the space width must be cleared.
///     style: TextStyle(font: myCjkFont, wordSpacing: 0),
///   ),
///   lineSplitter: (line) => line.split(''),
/// );
/// ```
///
/// Whitespace runs must be returned the same way [String.split] does (as empty
/// strings) when they are expected to keep their width, so that the default
/// behavior is preserved for mixed content.
typedef LineSplitter = List<String> Function(String line);

class RichText extends Widget with SpanningWidget {
  RichText({
    required this.text,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.tightBounds = false,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.overflow = TextOverflow.visible,
    this.hyphenation,
    this.lineSplitter,
  });

  static bool debug = false;

  final InlineSpan text;

  final TextAlign? textAlign;

  late TextAlign _textAlign;

  final TextDirection? textDirection;

  final double textScaleFactor;

  final bool? softWrap;

  final bool tightBounds;

  final int? maxLines;

  final List<_Span> _spans = <_Span>[];

  final List<_TextDecoration> _decorations = <_TextDecoration>[];

  final _context = RichTextContext();

  final TextOverflow? overflow;

  var _mustClip = false;

  List<InlineSpan>? _preprocessed;

  final Hyphenation? hyphenation;

  /// A custom function to split lines of text into words that may be wrapped
  /// independently. When `null` (the default), lines are split at whitespace.
  ///
  /// See [LineSplitter] for details and for an example enabling CJK wrapping.
  final LineSplitter? lineSplitter;

  void _appendDecoration(bool append, _TextDecoration td) {
    if (append && _decorations.isNotEmpty) {
      final last = _decorations.last;
      if (last.style == td.style && last.annotation == td.annotation) {
        _decorations[_decorations.length - 1] = last.copyWith(
          endSpan: td.endSpan,
        );
        return;
      }
    }
    _decorations.add(td);
  }

  InlineSpan _addEmoji({
    required TtfBitmapInfo bitmap,
    double baseline = 0,
    required TextStyle style,
    AnnotationBuilder? annotation,
  }) {
    final metrics = bitmap.metrics * style.fontSize!;

    return WidgetSpan(
      child: SizedBox(
        height: style.fontSize,
        child: Image(MemoryImage(bitmap.data)),
      ),
      style: style,
      baseline: baseline + metrics.ascent + metrics.descent - metrics.height,
      annotation: annotation,
    );
  }

  InlineSpan _addText({
    required List<int> text,
    int start = 0,
    int? end,
    double baseline = 0,
    required TextStyle style,
    AnnotationBuilder? annotation,
  }) {
    return TextSpan(
      text: String.fromCharCodes(text, start, end),
      style: style,
      baseline: baseline,
      annotation: annotation,
    );
  }

  InlineSpan _addPlaceholder({
    double baseline = 0,
    required TextStyle style,
    AnnotationBuilder? annotation,
  }) {
    return WidgetSpan(
      child: SizedBox(
        height: style.fontSize,
        width: style.fontSize! / 2,
        child: Placeholder(color: style.color!, strokeWidth: 1),
      ),
      style: style,
      baseline: baseline,
      annotation: annotation,
    );
  }

  /// Check available characters in the fonts
  /// use fallback if needed and replace emojis
  List<InlineSpan> _preProcessSpans(Context context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.defaultTextStyle;
    final spans = <InlineSpan>[];

    text.visitChildren(
      (InlineSpan span, TextStyle? style, AnnotationBuilder? annotation) {
        if (span is! TextSpan) {
          spans.add(span.copyWith(style: style, annotation: annotation));
          return true;
        }
        if (span.text == null) {
          return true;
        }

        final font = style!.font!.getFont(context);

        final runes = span.text!.runes.toList();

        // One span per maximal run of runes served by the same font. A span was
        // emitted for each unsupported rune on its own, so a fallback-served
        // Arabic word arrived as a string of one-character spans - and shaping
        // works on a span, so every letter could only come out in its isolated
        // form, each became its own word for wrapping, and justify stretched the
        // gaps between letters.
        Font? served;
        var start = 0;

        void flush(int end) {
          if (end <= start) {
            return;
          }

          spans.add(
            _addText(
              text: runes,
              start: start,
              end: end,
              style: served == null
                  ? style
                  : style.copyWith(
                      font: served,
                      fontNormal: served,
                      fontBold: served,
                      fontBoldItalic: served,
                      fontItalic: served,
                    ),
              baseline: span.baseline,
              annotation: annotation,
            ),
          );

          start = end;
        }

        for (var index = 0; index < runes.length; index++) {
          final rune = runes[index];
          const spaces = {
            0x0a,
            0x0b,
            0x0c,
            0x0d,
            0x09,
            0x00A0,
            0x1680,
            0x2000,
            0x2001,
            0x2002,
            0x2003,
            0x2004, //
            0x2005,
            0x2006,
            0x2007,
            0x2008,
            0x2009,
            0x200A,
            0x202F,
            0x205F,
            0x2028,
            0x2029,
            0x3000,
          };
          // Whitespace stays with whatever run is open, so a space cannot chop a
          // sentence in two. A default ignorable is never drawn, so it must not
          // reach the fallback scan either: with no font covering it the scan
          // ended at _addPlaceholder and painted a crossed box for a soft hyphen,
          // a variation selector or a bidi mark.
          if (spaces.contains(rune) || isDefaultIgnorable(rune)) {
            continue;
          }

          if (font.isRuneSupported(rune)) {
            if (served != null) {
              flush(index);
              served = null;
            }
            continue;
          }

          // The span's own font cannot draw it. Take the first fallback that can.
          Font? fallback;
          TtfBitmapInfo? bitmap;
          for (final candidate in style.fontFallback) {
            final resolved = candidate.getFont(context);
            if (!resolved.isRuneSupported(rune)) {
              continue;
            }
            fallback = candidate;
            if (resolved is PdfTtfFont) {
              bitmap = resolved.font.getBitmap(rune);
            }
            break;
          }

          if (bitmap != null) {
            // An emoji is its own object: it ends the run before it and starts a
            // new one after it.
            flush(index);
            spans.add(
              _addEmoji(
                bitmap: bitmap,
                style: style,
                baseline: span.baseline,
                annotation: annotation,
              ),
            );
            start = index + 1;
            served = null;
            continue;
          }

          if (fallback != null) {
            if (served != fallback) {
              flush(index);
              served = fallback;
            }
            continue;
          }

          flush(index);
          spans.add(
            _addPlaceholder(
              style: style,
              baseline: span.baseline,
              annotation: annotation,
            ),
          );
          start = index + 1;
          served = null;

          assert(() {
            print(
              'Unable to find a font to draw "${String.fromCharCode(rune)}" (U+${rune.toRadixString(16)}) try to provide a TextStyle.fontFallback',
            );
            return true;
          }());
        }

        flush(runes.length);

        // Every rune was either written into a run or replaced by a widget.
        assert(
          start == runes.length,
          'the emitted spans have to cover the whole source text',
        );

        return true;
      },
      defaultStyle,
      null,
    );

    return spans;
  }

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    _spans.clear();
    _decorations.clear();

    final theme = Theme.of(context);
    final _softWrap = softWrap ?? theme.softWrap;
    final _maxLines = maxLines ?? theme.maxLines;
    final _textDirection = textDirection ?? Directionality.of(context);
    _textAlign = textAlign ?? theme.textAlign ?? TextAlign.start;

    final _overflow = this.overflow ?? theme.overflow;

    final constraintWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth();
    final constraintHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight();

    var offsetX = 0.0;
    var offsetY = _context.startOffset;

    var top = 0.0;
    var bottom = 0.0;

    final lines = <_Line>[];
    var spanCount = 0;
    var spanStart = 0;
    var overflow = false;

    _preprocessed ??= _preProcessSpans(context);

    // Whether the bidi algorithm shapes and reorders this paragraph.
    //
    // It used to run only when the resolved direction was rtl, and
    // Directionality defaults to ltr, so an Arabic or Hebrew fragment inside an
    // English paragraph - a name, an address line, a currency symbol - got no
    // reordering and no shaping and came out backwards and unjoined. UAX #9 uses
    // the base direction to pick the embedding level, not to decide whether to
    // run at all. Text with nothing bidirectional in it is skipped, so a
    // left-to-right document is untouched.
    final _bidi =
        useBidi &&
        (_textDirection == TextDirection.rtl ||
            _preprocessed!.any(
              (InlineSpan span) =>
                  span is TextSpan &&
                  span.text != null &&
                  bidi.hasBidi(span.text!),
            ));

    void _buildLines() {
      for (final span in _preprocessed!) {
        final style = span.style;
        final annotation = span.annotation;

        if (span is TextSpan) {
          if (span.text == null) {
            continue;
          }

          final font = style!.font!.getFont(context);

          /// What one separator advances the pen by, measured in this font
          /// instead of assumed to be a U+0020: an em space, an ideographic
          /// space and a tab are nothing like a space wide.
          double gapOf(String separator) => separator.isEmpty
              ? 0
              : (font.stringMetrics(separator) *
                            (style.fontSize! * textScaleFactor))
                        .advanceWidth *
                    style.wordSpacing!;

          /// [text] with every whitespace character this font cannot draw
          /// replaced by a plain space.
          ///
          /// Whitespace carries its own width now, so a character the font does
          /// not map would advance by nothing: no font has a glyph for U+0009,
          /// and hacen-tunisia has none for U+00A0. A U+0020 is what the layout
          /// charged for all of them before.
          String drawable(String text) {
            if (!whitespace.hasMatch(text)) {
              return text;
            }

            return text.replaceAllMapped(whitespace, (Match match) {
              final found = match.group(0)!;
              final rune = found.codeUnitAt(0);
              return rune < 0x20 || !font.isRuneSupported(rune) ? ' ' : found;
            });
          }

          // The strip runs after the shaping and the bidi reordering, which both
          // need the joiners and the bidi marks, and before the line split, so
          // no invisible character is ever measured or drawn. U+000D is a line
          // terminator: the split used to look for U+000A alone, so a document
          // written with CRLF or CR line endings ran every line together and
          // drew a placeholder box at each break.
          final spanLines = stripDefaultIgnorable(
            (useArabic && _textDirection == TextDirection.rtl
                ? arabic.convert(span.text!)
                : _bidi
                // Shaped, but still in logical order: line breaking, metrics
                // and hyphenation all need that, and rule L2 belongs to a
                // finished line. Reordering the paragraph first and reversing
                // its word order cancelled out only while every word of a run
                // stayed on one line.
                ? bidi.shapeLogical(span.text!)
                : span.text)!,
            // The soft hyphen, the zero-width space and the word joiner are
            // break opportunities: tokenize reads them and drops them.
            keep: breakControls,
          ).split(RegExp(r'\r\n|\r|\n'));

          // The gap charged after the last run. The line-closing sites take it
          // back out, so a line's width ends at its last glyph.
          var lastGap = 0.0;

          for (var line = 0; line < spanLines.length; line++) {
            final chunks = lineSplitter == null
                ? tokenize(spanLines[line])
                : <TextChunk>[
                    // A caller-supplied splitter says nothing about what it
                    // took out, so every run keeps the U+0020 it always got. It
                    // is also the authority on where lines break, so the break
                    // controls are dropped here without becoming opportunities.
                    for (final word in lineSplitter!(spanLines[line]))
                      TextChunk(stripDefaultIgnorable(word), ' '),
                  ];
            for (var index = 0; index < chunks.length; index++) {
              final chunk = chunks[index];
              final word = drawable(chunk.text);

              if (word.isEmpty) {
                // No glyphs, so no letter spacing to make up for: the spacing
                // added after a run compensates for the trailing one
                // PdfFontMetrics.append leaves out of the advance, and an empty
                // run has no trailing glyph. Charging it moved every word after
                // a run of whitespace, so splitting text into spans shifted it.
                lastGap = gapOf(drawable(chunk.separator));
                offsetX += lastGap;
                continue;
              }

              final metrics = _metricsOf(word, font, style);

              if (_softWrap &&
                  offsetX + metrics.width > constraintWidth + 0.00001) {
                if (hyphenation != null) {
                  final syllables = hyphenation!(word);
                  if (syllables.length > 1) {
                    var fits = '';
                    for (var syllable in syllables) {
                      if (offsetX +
                              ((font.stringMetrics(
                                        '$fits$syllable-',
                                        letterSpacing:
                                            style.letterSpacing! /
                                            (style.fontSize! * textScaleFactor),
                                      ) *
                                      (style.fontSize! * textScaleFactor))
                                  .width) >
                          constraintWidth + 0.00001) {
                        break;
                      }
                      fits += syllable;
                    }
                    if (fits.isNotEmpty) {
                      chunks[index] = TextChunk('$fits-', '');
                      chunks.insert(
                        index + 1,
                        TextChunk(word.substring(fits.length), chunk.separator),
                      );
                      index--;
                      continue;
                    }
                  }
                }

                if (spanCount > 0 && metrics.width <= constraintWidth) {
                  overflow = true;
                  if (_bidi) {
                    _reorderVisual(
                      spanStart,
                      spanCount,
                      offsetX,
                      _textDirection == TextDirection.rtl,
                    );
                  }
                  lines.add(
                    _Line(
                      this,
                      spanStart,
                      spanCount,
                      bottom,
                      offsetX - lastGap - style.letterSpacing!,
                      _textDirection,
                      true,
                    ),
                  );

                  spanStart += spanCount;
                  spanCount = 0;

                  offsetX = 0.0;
                  offsetY += bottom - top;
                  top = 0;
                  bottom = 0;

                  if (_maxLines != null && lines.length >= _maxLines) {
                    return;
                  }

                  if (offsetY > constraintHeight) {
                    return;
                  }

                  offsetY += style.lineSpacing! * textScaleFactor;
                } else {
                  // One word Overflow. Break it where it is meant to break
                  // before falling back to a width search that knows nothing
                  // about the text.
                  final at = _lastBreakThatFits(
                    chunk.breaks,
                    word,
                    font,
                    style,
                    constraintWidth,
                  );

                  if (at != null) {
                    chunks[index] = TextChunk(
                      word.substring(0, at.offset) + (at.hyphen ? '-' : ''),
                      '',
                    );
                    chunks.insert(
                      index + 1,
                      TextChunk(
                        word.substring(at.offset),
                        chunk.separator,
                        <TextBreak>[
                          for (final rest in chunk.breaks)
                            if (rest.offset > at.offset)
                              TextBreak(
                                rest.offset - at.offset,
                                hyphen: rest.hyphen,
                              ),
                        ],
                      ),
                    );

                    index--;
                    continue;
                  }

                  final pos = _splitWord(word, font, style, constraintWidth);

                  if (pos < word.length) {
                    chunks[index] = TextChunk(word.substring(0, pos), '');
                    chunks.insert(
                      index + 1,
                      TextChunk(word.substring(pos), chunk.separator),
                    );

                    // Try again
                    index--;
                    continue;
                  }

                  if (spanCount == 0 && offsetX > 0) {
                    // The word fits a line of its own and only the leading
                    // whitespace pushed it over the edge. Drop that
                    // whitespace rather than splitting a word that fits.
                    offsetX = 0.0;
                  }
                }
              }

              final baseline = span.baseline * textScaleFactor;
              final mt = tightBounds ? metrics.top : metrics.descent;
              final mb = tightBounds ? metrics.bottom : metrics.ascent;
              top = math.min(top, mt + baseline);
              bottom = math.max(bottom, mb + baseline);

              // A right-to-left run reads backwards on the page, and every
              // consumer of the span - the drawn string and its own metrics -
              // has to agree on that.
              final visual = _bidi && bidi.isRtlText(word)
                  ? bidi.reversed(word)
                  : word;
              final wd = _Word(
                visual,
                style,
                visual == word ? metrics : _metricsOf(visual, font, style),
              );
              wd.offset = PdfPoint(offsetX, -offsetY + baseline);
              _spans.add(wd);
              spanCount++;

              _appendDecoration(
                spanCount > 1,
                _TextDecoration(
                  style,
                  annotation,
                  _spans.length - 1,
                  _spans.length - 1,
                ),
              );

              lastGap = gapOf(drawable(chunk.separator));
              offsetX += metrics.advanceWidth + lastGap + style.letterSpacing!;
            }

            if (line < spanLines.length - 1) {
              if (_bidi) {
                _reorderVisual(
                  spanStart,
                  spanCount,
                  offsetX,
                  _textDirection == TextDirection.rtl,
                );
              }
              lines.add(
                _Line(
                  this,
                  spanStart,
                  spanCount,
                  bottom,
                  offsetX - lastGap - style.letterSpacing!,
                  _textDirection,
                  false,
                ),
              );

              spanStart += spanCount;

              offsetX = 0.0;
              if (spanCount > 0) {
                offsetY += bottom - top;
              } else {
                offsetY +=
                    font.emptyLineHeight * style.fontSize! * textScaleFactor;
              }
              top = 0;
              bottom = 0;
              spanCount = 0;

              if (_maxLines != null && lines.length >= _maxLines) {
                return;
              }

              if (offsetY > constraintHeight) {
                return;
              }

              offsetY += style.lineSpacing! * textScaleFactor;
            }
          }

          // Take back the gap charged after the last run, but not its letter
          // spacing: PdfFontMetrics.append leaves the trailing one out of the
          // advance while the emitted Tc still applies it, so the next span
          // starts where continuous text would put it. This read
          // `-= lastGap - letterSpacing`, which parses as -(gap) + spacing
          // rather than -(gap + spacing), so every span boundary gained two
          // letter spacings of gap.
          offsetX -= lastGap;
        } else if (span is WidgetSpan) {
          span.child.layout(
            context,
            BoxConstraints(
              maxWidth: constraintWidth,
              maxHeight: constraintHeight,
            ),
          );
          final ws = _WidgetSpan(span.child, style!, span.baseline);

          if (offsetX + ws.width > constraintWidth && spanCount > 0) {
            overflow = true;
            if (_bidi) {
              _reorderVisual(
                spanStart,
                spanCount,
                offsetX,
                _textDirection == TextDirection.rtl,
              );
            }
            lines.add(
              _Line(
                this,
                spanStart,
                spanCount,
                bottom,
                offsetX,
                _textDirection,
                true,
              ),
            );

            spanStart += spanCount;
            spanCount = 0;

            if (_maxLines != null && lines.length > _maxLines) {
              return;
            }

            offsetX = 0.0;
            offsetY += bottom - top;
            top = 0;
            bottom = 0;

            if (offsetY > constraintHeight) {
              return;
            }

            offsetY += style.lineSpacing! * textScaleFactor;
          }

          final baseline = span.baseline * textScaleFactor;
          top = math.min(top, baseline);
          bottom = math.max(bottom, ws.height + baseline);

          ws.offset = PdfPoint(offsetX, -offsetY + baseline);
          _spans.add(ws);
          spanCount++;

          _appendDecoration(
            spanCount > 1,
            _TextDecoration(
              style,
              annotation,
              _spans.length - 1,
              _spans.length - 1,
            ),
          );

          offsetX += ws.left + ws.width;
        }
      }
    }

    _buildLines();

    if (spanCount > 0) {
      if (_bidi) {
        _reorderVisual(
          spanStart,
          spanCount,
          offsetX,
          _textDirection == TextDirection.rtl,
        );
      }
      lines.add(
        _Line(
          this,
          spanStart,
          spanCount,
          bottom,
          offsetX,
          _textDirection,
          false,
        ),
      );
      offsetY += bottom - top;
    }

    assert(!overflow || constraintWidth.isFinite);
    var width = overflow ? constraintWidth : constraints.minWidth;

    if (lines.isNotEmpty) {
      if (!overflow) {
        // Calculate the final width
        for (final line in lines) {
          width = math.max(width, line.wordsWidth);
        }
      }

      // Realign all the lines
      for (final line in lines) {
        line.realign(width);
      }
    }

    box = PdfRect(
      0,
      0,
      constraints.constrainWidth(width),
      constraints.constrainHeight(offsetY),
    );

    _context
      ..endOffset = offsetY - _context.startOffset
      ..spanEnd = _spans.length;

    if (_overflow != TextOverflow.span) {
      if (_overflow != TextOverflow.visible) {
        _mustClip = true;
      }
      return;
    }

    if (offsetY > constraintHeight + 0.0001) {
      _context.spanEnd -= lines.last.countSpan;
      _context.endOffset -= lines.last.height;
    }

    for (var index = 0; index < _decorations.length; index++) {
      final decoration = _decorations[index];
      if (decoration.startSpan >= _context.spanEnd ||
          decoration.endSpan < _context.spanStart) {
        _decorations.removeAt(index);
        index--;
      }
    }
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.blue)
      ..setLineWidth(1)
      ..drawRect(
        box!.left,
        box!.bottom,
        box!.width == double.infinity ? 1000 : box!.width,
        box!.height == double.infinity ? 1000 : box!.height,
      )
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    TextStyle? currentStyle;
    PdfColor? currentColor;

    if (_mustClip) {
      context.canvas
        ..saveContext()
        ..drawBox(box!)
        ..clipPath();
    }

    for (final decoration in _decorations) {
      assert(() {
        if (Document.debug && RichText.debug) {
          decoration.debugPaint(context, textScaleFactor, box!, _spans);
        }
        return true;
      }());

      decoration.backgroundPaint(context, textScaleFactor, box, _spans);
    }

    for (final span in _spans.sublist(_context.spanStart, _context.spanEnd)) {
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
        currentStyle!,
        textScaleFactor,
        PdfPoint(box!.left, box!.top),
      );
    }

    for (final decoration in _decorations) {
      decoration.foregroundPaint(context, textScaleFactor, box, _spans);
    }

    if (_mustClip) {
      context.canvas.restoreContext();
    }
  }

  /// The metrics [text] lays out to in this style.
  PdfFontMetrics _metricsOf(String text, PdfFont font, TextStyle style) =>
      font.stringMetrics(
        text,
        letterSpacing:
            style.letterSpacing! / (style.fontSize! * textScaleFactor),
      ) *
      (style.fontSize! * textScaleFactor);

  /// The width [text] lays out to in this style.
  double _textWidth(String text, PdfFont font, TextStyle style) =>
      _metricsOf(text, font, style).width;

  /// Put one finished line into visual order.
  ///
  /// UAX #9 rule L2 applies to a line once its breaks are known, so it cannot be
  /// done to the paragraph up front: every line would get a slice of a reordered
  /// paragraph, and reordering a slice is not the same thing. That is why an
  /// embedded Latin run straddling a wrap point landed on the wrong lines.
  ///
  /// The spans keep their logical order in [_spans] - the page-break
  /// bookkeeping, the decorations and the span ranges all index them that way -
  /// and only their x offsets move. [lineEnd] is where the pen stopped, so each
  /// span's slot is the distance to the next one and the slots add up to what
  /// the line already measured.
  void _reorderVisual(int first, int count, double lineEnd, bool rtl) {
    if (count < 2) {
      return;
    }

    final spans = _spans.sublist(first, first + count);
    final order = bidi.reorderLine(<String>[
      for (final span in spans)
        // A widget has no text of its own. U+FFFC is what the algorithm expects
        // in its place: an object that takes the direction around it.
        if (span is _Word) span.text else '\uFFFC',
    ], rtl: rtl);

    // What each span advanced the pen by, and the gap that followed it. The
    // gap belongs between the two words it separates, wherever they end up, so
    // it cannot travel with one of them.
    final advance = <double>[
      for (final span in spans)
        if (span is _Word)
          span.metrics.advanceWidth
        else
          span.left + span.width,
    ];
    final gaps = <double>[
      for (var i = 0; i < count; i++)
        ((i + 1 < count ? spans[i + 1].offset.x : lineEnd) -
                spans[i].offset.x) -
            advance[i],
    ];

    var x = spans.first.offset.x;
    for (var at = 0; at < order.length; at++) {
      final index = order[at];
      spans[index].offset = PdfPoint(x, spans[index].offset.y);
      x += advance[index];

      if (at + 1 < order.length) {
        // The gap recorded after whichever of the two neighbours comes first
        // logically, which is the one that separated them.
        x += gaps[math.min(index, order[at + 1])];
      }
    }
  }

  /// The last break opportunity of [word] whose head still fits [maxWidth], or
  /// null if not even the first one does.
  ///
  /// [breaks] is ascending and each head is a prefix of the next, so the search
  /// stops at the first one that overflows.
  TextBreak? _lastBreakThatFits(
    List<TextBreak> breaks,
    String word,
    PdfFont font,
    TextStyle style,
    double maxWidth,
  ) {
    TextBreak? fits;

    for (final at in breaks) {
      final head = word.substring(0, at.offset) + (at.hyphen ? '-' : '');
      if (_textWidth(head, font, style) > maxWidth + 0.00001) {
        break;
      }
      fits = at;
    }

    return fits;
  }

  /// Widest prefix of [word] that fits [maxWidth], as a UTF-16 offset
  ///
  /// The offset is always on a rune boundary: cutting between a surrogate pair
  /// leaves an unpaired surrogate in both halves, which no font can map, so
  /// the document would either draw an arbitrary glyph or fail to save. At
  /// least one rune is always consumed, so a caller that re-queues the rest
  /// makes progress.
  int _splitWord(String word, PdfFont font, TextStyle style, double maxWidth) {
    double widthOf(int end) => _textWidth(word.substring(0, end), font, style);

    // Offsets just past each rune, so bounds.last == word.length.
    final bounds = <int>[];
    for (var i = 0; i < word.length;) {
      final unit = word.codeUnitAt(i);
      final isHighSurrogate = unit >= 0xd800 && unit <= 0xdbff;
      i += isHighSurrogate && i + 1 < word.length ? 2 : 1;
      bounds.add(i);
    }

    if (bounds.isEmpty) {
      return word.length;
    }

    // The whole word was never measured, so a word that fits was still split.
    if (widthOf(word.length) <= maxWidth) {
      return word.length;
    }

    var low = 0;
    var high = bounds.length;

    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (widthOf(bounds[mid - 1]) > maxWidth) {
        high = mid;
      } else {
        low = mid;
      }
    }

    return bounds[math.max(0, low - 1)];
  }

  @override
  bool get canSpan => overflow == TextOverflow.span;

  @override
  bool get hasMoreWidgets => canSpan && _context.spanEnd < _spans.length;

  @override
  void restoreContext(RichTextContext context) {
    _context.spanStart = context.spanEnd;
    _context.startOffset = -context.endOffset;
  }

  @override
  WidgetContext saveContext() {
    return _context;
  }
}

class Text extends RichText {
  Text(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    bool? softWrap,
    bool tightBounds = false,
    double textScaleFactor = 1.0,
    int? maxLines,
    TextOverflow? overflow,
    Hyphenation? hyphenation,
    LineSplitter? lineSplitter,
  }) : super(
         text: TextSpan(text: text, style: style),
         textAlign: textAlign,
         softWrap: softWrap,
         tightBounds: tightBounds,
         textDirection: textDirection,
         textScaleFactor: textScaleFactor,
         maxLines: maxLines,
         overflow: overflow,
         hyphenation: hyphenation,
         lineSplitter: lineSplitter,
       );
}
