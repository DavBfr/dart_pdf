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
    this.color = PdfColors.black,
    @required this.font,
    this.fontSize = _defaultFontSize,
    this.letterSpacing = 1.0,
    this.wordSpacing = 1.0,
    this.lineSpacing = 0.0,
    this.height = 1.0,
    this.background,
  })  : assert(font != null),
        assert(color != null);

  final PdfColor color;

  final Font font;

  // font height, in pdf unit
  final double fontSize;

  static const double _defaultFontSize = 12.0 * PdfPageFormat.point;

  // spacing between letters, 1.0 being natural spacing
  final double letterSpacing;

  // spacing between lines, in pdf unit
  final double lineSpacing;

  // spacing between words, 1.0 being natural spacing
  final double wordSpacing;

  final double height;

  final PdfColor background;

  TextStyle copyWith({
    PdfColor color,
    Font font,
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

  @override
  String toString() =>
      'TextStyle(color:$color font:$font letterSpacing:$letterSpacing wordSpacing:$wordSpacing lineSpacing:$lineSpacing height:$height background:$background)';
}

@immutable
class Theme extends Inherited {
  Theme({
    @required this.defaultTextStyle,
    @required this.defaultTextStyleBold,
    @required this.paragraphStyle,
    @required this.header0,
    @required this.header1,
    @required this.header2,
    @required this.header3,
    @required this.header4,
    @required this.header5,
    @required this.bulletStyle,
    @required this.tableHeader,
    @required this.tableCell,
  });

  factory Theme.withFont(Font baseFont, Font baseFontBold) {
    final TextStyle defaultTextStyle = TextStyle(font: baseFont);
    final TextStyle defaultTextStyleBold = TextStyle(font: baseFontBold);
    final double fontSize = defaultTextStyle.fontSize;

    return Theme(
        defaultTextStyle: defaultTextStyle,
        defaultTextStyleBold: defaultTextStyleBold,
        paragraphStyle: defaultTextStyle.copyWith(lineSpacing: 5),
        bulletStyle: defaultTextStyle.copyWith(lineSpacing: 5),
        header0: defaultTextStyleBold.copyWith(fontSize: fontSize * 2.0),
        header1: defaultTextStyleBold.copyWith(fontSize: fontSize * 1.5),
        header2: defaultTextStyleBold.copyWith(fontSize: fontSize * 1.4),
        header3: defaultTextStyleBold.copyWith(fontSize: fontSize * 1.3),
        header4: defaultTextStyleBold.copyWith(fontSize: fontSize * 1.2),
        header5: defaultTextStyleBold.copyWith(fontSize: fontSize * 1.1),
        tableHeader: defaultTextStyleBold,
        tableCell: defaultTextStyle);
  }

  factory Theme.base() =>
      Theme.withFont(Font.helvetica(), Font.helveticaBold());

  static Theme of(Context context) {
    return context.inherited[Theme];
  }

  final TextStyle defaultTextStyle;

  final TextStyle defaultTextStyleBold;

  final TextStyle paragraphStyle;

  final TextStyle header0;
  final TextStyle header1;
  final TextStyle header2;
  final TextStyle header3;
  final TextStyle header4;
  final TextStyle header5;

  final TextStyle bulletStyle;

  final TextStyle tableHeader;

  final TextStyle tableCell;
}
