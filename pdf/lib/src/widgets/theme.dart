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

import 'package:meta/meta.dart';

import 'basic.dart';
import 'font.dart';
import 'icon.dart';
import 'text.dart';
import 'text_style.dart';
import 'widget.dart';

typedef DefaultThemeDataBuilder = ThemeData Function();

@immutable
class ThemeData extends Inherited {
  factory ThemeData({
    TextStyle? defaultTextStyle,
    TextStyle? paragraphStyle,
    TextStyle? header0,
    TextStyle? header1,
    TextStyle? header2,
    TextStyle? header3,
    TextStyle? header4,
    TextStyle? header5,
    TextStyle? bulletStyle,
    TextStyle? tableHeader,
    TextStyle? tableCell,
    bool? softWrap,
    TextAlign? textAlign,
    TextOverflow? overflow,
    int? maxLines,
    IconThemeData? iconTheme,
  }) {
    final base = ThemeData.base();
    return base.copyWith(
      defaultTextStyle: defaultTextStyle,
      paragraphStyle: paragraphStyle,
      bulletStyle: bulletStyle,
      header0: header0,
      header1: header1,
      header2: header2,
      header3: header3,
      header4: header4,
      header5: header5,
      tableHeader: tableHeader,
      tableCell: tableCell,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      maxLines: maxLines,
      iconTheme: iconTheme,
    );
  }

  ThemeData._({
    required this.defaultTextStyle,
    required this.paragraphStyle,
    required this.header0,
    required this.header1,
    required this.header2,
    required this.header3,
    required this.header4,
    required this.header5,
    required this.bulletStyle,
    required this.tableHeader,
    required this.tableCell,
    required this.softWrap,
    required this.overflow,
    required this.iconTheme,
    this.textAlign,
    this.maxLines,
  })  : assert(defaultTextStyle.inherit == false),
        assert(paragraphStyle.inherit == false),
        assert(header0.inherit == false),
        assert(header1.inherit == false),
        assert(header2.inherit == false),
        assert(header3.inherit == false),
        assert(header4.inherit == false),
        assert(header5.inherit == false),
        assert(bulletStyle.inherit == false),
        assert(tableHeader.inherit == false),
        assert(tableCell.inherit == false),
        assert(maxLines == null || maxLines > 0);

  factory ThemeData.withFont({
    Font? base,
    Font? bold,
    Font? italic,
    Font? boldItalic,
    Font? icons,
    List<Font>? fontFallback,
  }) {
    final defaultStyle = TextStyle.defaultStyle().copyWith(
      font: base,
      fontNormal: base,
      fontBold: bold,
      fontItalic: italic,
      fontBoldItalic: boldItalic,
      fontFallback: fontFallback,
    );
    final fontSize = defaultStyle.fontSize!;

    return ThemeData._(
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
      tableCell: defaultStyle.copyWith(fontSize: fontSize * 0.8),
      softWrap: true,
      overflow: TextOverflow.visible,
      iconTheme: IconThemeData.fallback(icons),
    );
  }

  factory ThemeData.base() =>
      buildThemeData == null ? ThemeData.withFont() : buildThemeData!();

  static DefaultThemeDataBuilder? buildThemeData;

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

  final TextAlign? textAlign;
  final bool softWrap;
  final int? maxLines;
  final TextOverflow overflow;

  final IconThemeData iconTheme;

  ThemeData copyWith({
    TextStyle? defaultTextStyle,
    TextStyle? paragraphStyle,
    TextStyle? header0,
    TextStyle? header1,
    TextStyle? header2,
    TextStyle? header3,
    TextStyle? header4,
    TextStyle? header5,
    TextStyle? bulletStyle,
    TextStyle? tableHeader,
    TextStyle? tableCell,
    bool? softWrap,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    IconThemeData? iconTheme,
  }) =>
      ThemeData._(
        defaultTextStyle: this.defaultTextStyle.merge(defaultTextStyle),
        paragraphStyle: this.paragraphStyle.merge(paragraphStyle),
        bulletStyle: this.bulletStyle.merge(bulletStyle),
        header0: this.header0.merge(header0),
        header1: this.header1.merge(header1),
        header2: this.header2.merge(header2),
        header3: this.header3.merge(header3),
        header4: this.header4.merge(header4),
        header5: this.header5.merge(header5),
        tableHeader: this.tableHeader.merge(tableHeader),
        tableCell: this.tableCell.merge(tableCell),
        softWrap: softWrap ?? this.softWrap,
        overflow: overflow ?? this.overflow,
        textAlign: textAlign ?? this.textAlign,
        maxLines: maxLines ?? this.maxLines,
        iconTheme: iconTheme ?? this.iconTheme,
      );
}

class Theme extends StatelessWidget {
  Theme({
    required this.data,
    required this.child,
  });

  final ThemeData data;

  final Widget child;

  static ThemeData of(Context context) {
    return context.dependsOn<ThemeData>()!;
  }

  @override
  Widget build(Context context) {
    return InheritedWidget(
      inherited: data,
      build: (Context context) => child,
    );
  }
}

class DefaultTextStyle extends StatelessWidget implements Inherited {
  DefaultTextStyle({
    required this.style,
    required this.child,
    this.textAlign,
    this.softWrap = true,
    this.overflow,
    this.maxLines,
  }) : assert(maxLines == null || maxLines > 0);

  static Widget merge({
    TextStyle? style,
    TextAlign? textAlign,
    bool? softWrap,
    int? maxLines,
    TextOverflow? overflow,
    required Widget child,
  }) {
    return Builder(
      builder: (Context context) {
        final parent = Theme.of(context);

        return DefaultTextStyle(
          style: parent.defaultTextStyle.merge(style),
          textAlign: textAlign ?? parent.textAlign,
          softWrap: softWrap ?? parent.softWrap,
          overflow: overflow ?? parent.overflow,
          maxLines: maxLines ?? parent.maxLines,
          child: child,
        );
      },
    );
  }

  final TextStyle style;

  final Widget child;

  final TextAlign? textAlign;

  final bool softWrap;

  final int? maxLines;

  final TextOverflow? overflow;

  @override
  Widget build(Context context) {
    final theme = Theme.of(context).copyWith(
      defaultTextStyle: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );

    return InheritedWidget(
      inherited: theme,
      build: (Context context) => child,
    );
  }
}
