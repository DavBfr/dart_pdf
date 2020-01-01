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

class _BarcodeWidget extends Widget {
  _BarcodeWidget({
    @required this.data,
    this.barcode,
    this.color = PdfColors.black,
    this.drawText,
    this.textStyle,
  });

  /// the barcode data
  final String data;

  final Barcode barcode;

  final PdfColor color;

  final bool drawText;

  final TextStyle textStyle;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final List<BarcodeText> textList = <BarcodeText>[];

    for (BarcodeElement element in barcode.make(
      data,
      width: box.width,
      height: box.height,
      drawText: drawText,
      fontHeight: textStyle.fontSize,
    )) {
      if (element is BarcodeBar) {
        if (element.black) {
          context.canvas.drawRect(
            box.left + element.left,
            box.top - element.top - element.height,
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

    if (drawText) {
      final PdfFont font = textStyle.font.getFont(context);

      for (BarcodeText text in textList) {
        final PdfFontMetrics metrics = font.stringMetrics(text.text);

        final double top = box.top -
            text.top -
            metrics.descent * textStyle.fontSize -
            text.height;

        double left;
        switch (text.align) {
          case BarcodeTextAlign.left:
            left = text.left + box.left;
            break;
          case BarcodeTextAlign.center:
            left = text.left +
                box.left +
                (text.width - metrics.width * text.height) / 2;
            break;
          case BarcodeTextAlign.right:
            left = text.left +
                box.left +
                (text.width - metrics.width * text.height);
            break;
        }

        context.canvas
          ..setFillColor(textStyle.color)
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

    if (drawText) {
      for (BarcodeElement element in barcode.make(
        data,
        width: box.width,
        height: box.height,
        drawText: drawText,
        fontHeight: textStyle.fontSize,
      )) {
        if (element is BarcodeText) {
          context.canvas.drawRect(
            box.x + element.left,
            box.y + box.height - element.top - element.height,
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

class BarcodeWidget extends StatelessWidget {
  BarcodeWidget({
    @required this.data,
    @Deprecated('Use `Barcode.fromType(type)` instead')
        BarcodeType type = BarcodeType.Code39,
    Barcode barcode,
    this.color = PdfColors.black,
    this.backgroundColor,
    this.decoration,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.drawText = true,
    this.textStyle,
  }) :
        // ignore: deprecated_member_use_from_same_package
        barcode = barcode ?? Barcode.fromType(type);

  /// the barcode data
  final String data;

  final Barcode barcode;

  final PdfColor color;

  final PdfColor backgroundColor;

  final EdgeInsets padding;

  final EdgeInsets margin;

  final double width;

  final double height;

  final bool drawText;

  final TextStyle textStyle;

  final BoxDecoration decoration;

  @override
  Widget build(Context context) {
    final TextStyle defaultstyle = Theme.of(context).defaultTextStyle.copyWith(
          font: Font.courier(),
          fontNormal: Font.courier(),
          fontBold: Font.courierBold(),
          fontItalic: Font.courierOblique(),
          fontBoldItalic: Font.courierBoldOblique(),
          lineSpacing: 1,
        );
    final TextStyle _textStyle = defaultstyle.merge(textStyle);

    Widget child = _BarcodeWidget(
      data: data,
      color: color,
      barcode: barcode,
      drawText: drawText,
      textStyle: _textStyle,
    );

    if (padding != null) {
      child = Padding(padding: padding, child: child);
    }

    if (decoration != null) {
      child = DecoratedBox(
        decoration: decoration,
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
      child = Padding(padding: margin, child: child);
    }

    return child;
  }
}
