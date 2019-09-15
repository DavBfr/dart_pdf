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

enum FontWeight { normal, bold }

enum FontStyle { normal, italic }

enum TextDecorationStyle { solid, double }

/// A linear decoration to draw near the text.
class TextDecoration {
  const TextDecoration._(this._mask);

  /// Creates a decoration that paints the union of all the given decorations.
  factory TextDecoration.combine(List<TextDecoration> decorations) {
    int mask = 0;
    for (TextDecoration decoration in decorations) {
      mask |= decoration._mask;
    }
    return TextDecoration._(mask);
  }

  final int _mask;

  /// Whether this decoration will paint at least as much decoration as the given decoration.
  bool contains(TextDecoration other) {
    return (_mask | other._mask) == _mask;
  }

  /// Do not draw a decoration
  static const TextDecoration none = TextDecoration._(0x0);

  /// Draw a line underneath each line of text
  static const TextDecoration underline = TextDecoration._(0x1);

  /// Draw a line above each line of text
  static const TextDecoration overline = TextDecoration._(0x2);

  /// Draw a line through each line of text
  static const TextDecoration lineThrough = TextDecoration._(0x4);

  @override
  bool operator ==(dynamic other) {
    if (other is! TextDecoration) {
      return false;
    }
    final TextDecoration typedOther = other;
    return _mask == typedOther._mask;
  }

  @override
  int get hashCode => _mask.hashCode;

  @override
  String toString() {
    if (_mask == 0) {
      return 'TextDecoration.none';
    }
    final List<String> values = <String>[];
    if (_mask & underline._mask != 0) {
      values.add('underline');
    }
    if (_mask & overline._mask != 0) {
      values.add('overline');
    }
    if (_mask & lineThrough._mask != 0) {
      values.add('lineThrough');
    }
    if (values.length == 1) {
      return 'TextDecoration.${values[0]}';
    }
    return 'TextDecoration.combine([${values.join(", ")}])';
  }
}

@immutable
class TextStyle {
  const TextStyle({
    this.inherit = true,
    this.color,
    Font font,
    Font fontNormal,
    Font fontBold,
    Font fontItalic,
    Font fontBoldItalic,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.letterSpacing,
    this.wordSpacing,
    this.lineSpacing,
    this.height,
    this.background,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
  })  : assert(inherit || color != null),
        assert(inherit || font != null),
        assert(inherit || fontSize != null),
        assert(inherit || fontWeight != null),
        assert(inherit || fontStyle != null),
        assert(inherit || letterSpacing != null),
        assert(inherit || wordSpacing != null),
        assert(inherit || lineSpacing != null),
        assert(inherit || height != null),
        assert(inherit || decoration != null),
        assert(inherit || decorationColor != null),
        assert(inherit || decorationStyle != null),
        assert(inherit || decorationThickness != null),
        fontNormal = fontNormal ??
            (fontStyle != FontStyle.italic && fontWeight != FontWeight.bold
                ? font
                : null),
        fontBold = fontBold ??
            (fontStyle != FontStyle.italic && fontWeight == FontWeight.bold
                ? font
                : null),
        fontItalic = fontItalic ??
            (fontStyle == FontStyle.italic && fontWeight != FontWeight.bold
                ? font
                : null),
        fontBoldItalic = fontBoldItalic ??
            (fontStyle == FontStyle.italic && fontWeight == FontWeight.bold
                ? font
                : null);

  factory TextStyle.defaultStyle() {
    return TextStyle(
      color: PdfColors.black,
      fontNormal: Font.helvetica(),
      fontBold: Font.helveticaBold(),
      fontItalic: Font.helveticaOblique(),
      fontBoldItalic: Font.helveticaBoldOblique(),
      fontSize: _defaultFontSize,
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      letterSpacing: 1.0,
      wordSpacing: 1.0,
      lineSpacing: 0.0,
      height: 1.0,
      decoration: TextDecoration.none,
      decorationColor: null,
      decorationStyle: TextDecorationStyle.solid,
      decorationThickness: 1,
    );
  }

  final bool inherit;

  final PdfColor color;

  final Font fontNormal;

  final Font fontBold;

  final Font fontItalic;

  final Font fontBoldItalic;

  // font height, in pdf unit
  final double fontSize;

  /// The typeface thickness to use when painting the text (e.g., bold).
  final FontWeight fontWeight;

  /// The typeface variant to use when drawing the letters (e.g., italics).
  final FontStyle fontStyle;

  static const double _defaultFontSize = 12.0 * PdfPageFormat.point;

  // spacing between letters, 1.0 being natural spacing
  final double letterSpacing;

  // spacing between lines, in pdf unit
  final double lineSpacing;

  // spacing between words, 1.0 being natural spacing
  final double wordSpacing;

  final double height;

  final BoxDecoration background;

  final TextDecoration decoration;

  final PdfColor decorationColor;

  final TextDecorationStyle decorationStyle;

  final double decorationThickness;

  TextStyle copyWith({
    PdfColor color,
    Font font,
    Font fontNormal,
    Font fontBold,
    Font fontItalic,
    Font fontBoldItalic,
    double fontSize,
    FontWeight fontWeight,
    FontStyle fontStyle,
    double letterSpacing,
    double wordSpacing,
    double lineSpacing,
    double height,
    BoxDecoration background,
    TextDecoration decoration,
    PdfColor decorationColor,
    TextDecorationStyle decorationStyle,
    double decorationThickness,
  }) {
    return TextStyle(
      inherit: inherit,
      color: color ?? this.color,
      font: font ?? this.font,
      fontNormal: fontNormal ?? this.fontNormal,
      fontBold: fontBold ?? this.fontBold,
      fontItalic: fontItalic ?? this.fontItalic,
      fontBoldItalic: fontBoldItalic ?? this.fontBoldItalic,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      height: height ?? this.height,
      background: background ?? this.background,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness ?? this.decorationThickness,
    );
  }

  /// Creates a copy of this text style replacing or altering the specified
  /// properties.
  TextStyle apply({
    PdfColor color,
    Font font,
    Font fontNormal,
    Font fontBold,
    Font fontItalic,
    Font fontBoldItalic,
    double fontSizeFactor = 1.0,
    double fontSizeDelta = 0.0,
    double letterSpacingFactor = 1.0,
    double letterSpacingDelta = 0.0,
    double wordSpacingFactor = 1.0,
    double wordSpacingDelta = 0.0,
    double heightFactor = 1.0,
    double heightDelta = 0.0,
    TextDecoration decoration = TextDecoration.none,
  }) {
    assert(fontSizeFactor != null);
    assert(fontSizeDelta != null);
    assert(fontSize != null || (fontSizeFactor == 1.0 && fontSizeDelta == 0.0));
    assert(letterSpacingFactor != null);
    assert(letterSpacingDelta != null);
    assert(letterSpacing != null ||
        (letterSpacingFactor == 1.0 && letterSpacingDelta == 0.0));
    assert(wordSpacingFactor != null);
    assert(wordSpacingDelta != null);
    assert(wordSpacing != null ||
        (wordSpacingFactor == 1.0 && wordSpacingDelta == 0.0));
    assert(heightFactor != null);
    assert(heightDelta != null);
    assert(heightFactor != null || (heightFactor == 1.0 && heightDelta == 0.0));
    assert(decoration != null);

    return TextStyle(
      inherit: inherit,
      color: color ?? this.color,
      font: font ?? this.font,
      fontNormal: fontNormal ?? this.fontNormal,
      fontBold: fontBold ?? this.fontBold,
      fontItalic: fontItalic ?? this.fontItalic,
      fontBoldItalic: fontBoldItalic ?? this.fontBoldItalic,
      fontSize:
          fontSize == null ? null : fontSize * fontSizeFactor + fontSizeDelta,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing == null
          ? null
          : letterSpacing * letterSpacingFactor + letterSpacingDelta,
      wordSpacing: wordSpacing == null
          ? null
          : wordSpacing * wordSpacingFactor + wordSpacingDelta,
      height: height == null ? null : height * heightFactor + heightDelta,
      background: background,
      decoration: decoration,
    );
  }

  /// Returns a new text style that is a combination of this style and the given
  /// [other] style.
  TextStyle merge(TextStyle other) {
    if (other == null) {
      return this;
    }

    if (!other.inherit) {
      return other;
    }

    return copyWith(
      color: other.color,
      font: other.font,
      fontNormal: other.fontNormal,
      fontBold: other.fontBold,
      fontItalic: other.fontItalic,
      fontBoldItalic: other.fontBoldItalic,
      fontSize: other.fontSize,
      fontWeight: other.fontWeight,
      fontStyle: other.fontStyle,
      letterSpacing: other.letterSpacing,
      wordSpacing: other.wordSpacing,
      lineSpacing: other.lineSpacing,
      height: other.height,
      background: other.background,
      decoration: other.decoration,
      decorationColor: other.decorationColor,
      decorationStyle: other.decorationStyle,
      decorationThickness: other.decorationThickness,
    );
  }

  @Deprecated('use font instead')
  Font get paintFont => font;

  Font get font {
    if (fontWeight != FontWeight.bold) {
      if (fontStyle != FontStyle.italic) {
        // normal
        return fontNormal ?? fontBold ?? fontItalic ?? fontBoldItalic;
      } else {
        // italic
        return fontItalic ?? fontNormal ?? fontBold ?? fontBoldItalic;
      }
    } else {
      if (fontStyle != FontStyle.italic) {
        // bold
        return fontBold ?? fontNormal ?? fontItalic ?? fontBoldItalic;
      } else {
        // bold + italic
        return fontBoldItalic ?? fontBold ?? fontItalic ?? fontNormal;
      }
    }
  }

  @override
  String toString() =>
      'TextStyle(color:$color font:$font size:$fontSize weight:$fontWeight style:$fontStyle letterSpacing:$letterSpacing wordSpacing:$wordSpacing lineSpacing:$lineSpacing height:$height background:$background decoration:$decoration decorationColor:$decorationColor decorationStyle:$decorationStyle decorationThickness:$decorationThickness)';
}
