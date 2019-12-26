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
  });

  /// the barcode data
  final String data;

  final Barcode barcode;

  final PdfColor color;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final BarcodeDraw draw = barcode.draw;
    if (draw is _BarcodeDraw) {
      draw
        ..canvas = context.canvas
        ..left = box.left
        ..top = box.top;
    }

    context.canvas.setFillColor(color);
    barcode.make(data, box.width, box.height);
    context.canvas.fillPath();
  }
}

class _BarcodeDraw extends BarcodeDraw {
  PdfGraphics canvas;
  double left;
  double top;

  @override
  void fillRect(
      double left, double top, double width, double height, bool black) {
    if (black) {
      canvas.drawRect(this.left + left, this.top + top - height, width, height);
    }
  }
}

class BarcodeWidget extends StatelessWidget {
  BarcodeWidget({
    @required this.data,
    this.type = BarcodeType.Code39,
    this.color = PdfColors.black,
    this.backgroundColor,
    this.decoration,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.drawText = true,
    this.textStyle,
  });

  /// the barcode data
  final String data;

  final BarcodeType type;

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
    final TextStyle _textStyle = textStyle ?? TextStyle(font: Font.courier());

    Widget barcode = _BarcodeWidget(
      data: data,
      color: color,
      barcode: Barcode.fromType(
        type: type,
        draw: _BarcodeDraw(),
      ),
    );

    if (drawText) {
      barcode = Column(
        children: <Widget>[
          Flexible(child: barcode),
          Text(
            data,
            style: _textStyle,
            textAlign: TextAlign.center,
            softWrap: false,
          ),
        ],
      );
    }

    if (padding != null) {
      barcode = Padding(padding: padding, child: barcode);
    }

    if (decoration != null) {
      barcode = DecoratedBox(
        decoration: decoration,
        child: barcode,
      );
    } else if (backgroundColor != null) {
      barcode = DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor),
        child: barcode,
      );
    }

    if (width != null || height != null) {
      barcode = SizedBox(width: width, height: height, child: barcode);
    }

    if (margin != null) {
      barcode = Padding(padding: margin, child: barcode);
    }

    return barcode;
  }
}
