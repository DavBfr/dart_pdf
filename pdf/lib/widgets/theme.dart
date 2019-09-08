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
class Theme extends Inherited {
  const Theme({
    @required this.defaultTextStyle,
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

  factory Theme.withFont({Font base, Font bold, Font italic, Font boldItalic}) {
    final TextStyle defaultStyle = TextStyle.defaultStyle().copyWith(
        font: base,
        fontNormal: base,
        fontBold: bold,
        fontItalic: italic,
        fontBoldItalic: boldItalic);
    final double fontSize = defaultStyle.fontSize;

    return Theme(
        defaultTextStyle: defaultStyle,
        paragraphStyle: defaultStyle.copyWith(lineSpacing: 5),
        bulletStyle: defaultStyle.copyWith(lineSpacing: 5),
        header0: defaultStyle.copyWith(fontSize: fontSize * 2.0),
        header1: defaultStyle.copyWith(fontSize: fontSize * 1.5),
        header2: defaultStyle.copyWith(fontSize: fontSize * 1.4),
        header3: defaultStyle.copyWith(fontSize: fontSize * 1.3),
        header4: defaultStyle.copyWith(fontSize: fontSize * 1.2),
        header5: defaultStyle.copyWith(fontSize: fontSize * 1.1),
        tableHeader: defaultStyle.copyWith(
            fontSize: fontSize * 0.8, fontWeight: FontWeight.bold),
        tableCell: defaultStyle.copyWith(fontSize: fontSize * 0.8));
  }

  factory Theme.base() => Theme.withFont();

  Theme copyWith({
    TextStyle defaultTextStyle,
    TextStyle paragraphStyle,
    TextStyle header0,
    TextStyle header1,
    TextStyle header2,
    TextStyle header3,
    TextStyle header4,
    TextStyle header5,
    TextStyle bulletStyle,
    TextStyle tableHeader,
    TextStyle tableCell,
  }) =>
      Theme(
          defaultTextStyle: defaultTextStyle ?? this.defaultTextStyle,
          paragraphStyle: paragraphStyle ?? this.paragraphStyle,
          bulletStyle: bulletStyle ?? this.bulletStyle,
          header0: header0 ?? this.header0,
          header1: header1 ?? this.header1,
          header2: header2 ?? this.header2,
          header3: header3 ?? this.header3,
          header4: header4 ?? this.header4,
          header5: header5 ?? this.header5,
          tableHeader: tableHeader ?? this.tableHeader,
          tableCell: tableCell ?? this.tableCell);

  static Theme of(Context context) {
    return context.inherited[Theme];
  }

  final TextStyle defaultTextStyle;

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
