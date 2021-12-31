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

import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';

import 'basic.dart';
import 'container.dart';
import 'decoration.dart';
import 'font.dart';
import 'geometry.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

class _BarcodeWidget extends Widget {
  _BarcodeWidget({
    required this.data,
    this.barcode,
    this.color = PdfColors.black,
    this.drawText,
    this.textStyle,
    this.textPadding,
  });

  /// the barcode data
  final Uint8List data;

  final Barcode? barcode;

  final PdfColor color;

  final bool? drawText;

  final TextStyle? textStyle;

  final double? textPadding;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final textList = <BarcodeText>[];

    for (final element in barcode!.makeBytes(
      data,
      width: box!.width,
      height: box!.height,
      drawText: drawText!,
      fontHeight: textStyle!.fontSize!,
      textPadding: textPadding!,
    )) {
      if (element is BarcodeBar) {
        if (element.black) {
          context.canvas.drawRect(
            box!.left + element.left,
            box!.top - element.top - element.height,
            element.width,
            element.height,
          );
        }
      } else if (element is BarcodeText) {
        textList.add(element);
      }
    }

    context.canvas
      ..setFillColor(color)
      ..fillPath();

    if (drawText!) {
      final font = textStyle!.font!.getFont(context);

      for (final text in textList) {
        final metrics = font.stringMetrics(text.text);

        final top = box!.top -
            text.top -
            metrics.descent * textStyle!.fontSize! -
            text.height;

        double? left;
        switch (text.align) {
          case BarcodeTextAlign.left:
            left = text.left + box!.left;
            break;
          case BarcodeTextAlign.center:
            left = text.left +
                box!.left +
                (text.width - metrics.width * text.height) / 2;
            break;
          case BarcodeTextAlign.right:
            left = text.left +
                box!.left +
                (text.width - metrics.width * text.height);
            break;
        }

        context.canvas
          ..setFillColor(textStyle!.color)
          ..drawString(
            font,
            text.height,
            text.text,
            left,
            top,
          );
      }
    }
  }

  @override
  void debugPaint(Context context) {
    super.debugPaint(context);

    if (drawText!) {
      for (final element in barcode!.makeBytes(
        data,
        width: box!.width,
        height: box!.height,
        drawText: drawText!,
        fontHeight: textStyle!.fontSize!,
        textPadding: textPadding!,
      )) {
        if (element is BarcodeText) {
          context.canvas.drawRect(
            box!.x + element.left,
            box!.y + box!.height - element.top - element.height,
            element.width,
            element.height,
          );
        }
      }

      context.canvas
        ..setStrokeColor(PdfColors.blue)
        ..setLineWidth(1)
        ..strokePath();
    }
  }
}

/// Draw a barcode using String data
class BarcodeWidget extends StatelessWidget {
  /// Create a BarcodeWidget
  factory BarcodeWidget({
    required String data,
    required Barcode barcode,
    PdfColor color = PdfColors.black,
    PdfColor? backgroundColor,
    BoxDecoration? decoration,
    EdgeInsets? margin,
    EdgeInsets? padding,
    double? width,
    double? height,
    bool drawText = true,
    TextStyle? textStyle,
    double textPadding = 0,
  }) =>
      BarcodeWidget.fromBytes(
        data: utf8.encoder.convert(data),
        barcode: barcode,
        color: color,
        backgroundColor: backgroundColor,
        decoration: decoration,
        margin: margin,
        padding: padding,
        width: width,
        height: height,
        drawText: drawText,
        textStyle: textStyle,
        textPadding: textPadding,
      );

  /// Draw a barcode using Uint8List data
  BarcodeWidget.fromBytes({
    required this.data,
    required this.barcode,
    this.color = PdfColors.black,
    this.backgroundColor,
    this.decoration,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.drawText = true,
    this.textStyle,
    this.textPadding = 0,
  });

  /// the barcode data
  final Uint8List data;

  /// The type of barcode to use.
  /// use:
  ///   * Barcode.code128()
  ///   * Barcode.ean13()
  ///   * ...
  final Barcode barcode;

  /// The bars color
  /// should be black or really dark color
  final PdfColor color;

  /// The background color.
  /// this should be white or really light color
  final PdfColor? backgroundColor;

  /// Padding to apply
  final EdgeInsets? padding;

  /// Margin to apply
  final EdgeInsets? margin;

  /// Width of the barcode with padding
  final double? width;

  /// Height of the barcode with padding
  final double? height;

  /// Whether to draw the text with the barcode
  final bool drawText;

  /// Text style to use to draw the text
  final TextStyle? textStyle;

  /// Padding to add between the text and the barcode
  final double textPadding;

  /// Decoration to apply to the barcode
  final BoxDecoration? decoration;

  @override
  Widget build(Context context) {
    final defaultstyle = Theme.of(context).defaultTextStyle.copyWith(
          font: Font.courier(),
          fontNormal: Font.courier(),
          fontBold: Font.courierBold(),
          fontItalic: Font.courierOblique(),
          fontBoldItalic: Font.courierBoldOblique(),
          lineSpacing: 1,
          fontSize: height != null ? height! * 0.2 : null,
        );
    final _textStyle = defaultstyle.merge(textStyle);

    Widget child = _BarcodeWidget(
      data: data,
      color: color,
      barcode: barcode,
      drawText: drawText,
      textStyle: _textStyle,
      textPadding: textPadding,
    );

    if (padding != null) {
      child = Padding(padding: padding!, child: child);
    }

    if (decoration != null) {
      child = DecoratedBox(
        decoration: decoration!,
        child: child,
      );
    } else if (backgroundColor != null) {
      child = DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor),
        child: child,
      );
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }

    if (margin != null) {
      child = Padding(padding: margin!, child: child);
    }

    return child;
  }
}
