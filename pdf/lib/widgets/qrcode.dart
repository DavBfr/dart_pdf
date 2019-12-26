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

typedef QrError = void Function(dynamic error);

class _QrCodeWidget extends Widget {
  _QrCodeWidget({
    @required String data,
    this.version,
    this.errorCorrectionLevel,
    this.color,
    this.onError,
    this.gapless = false,
  })  : assert(data != null),
        _qr = version == null
            ? QrCode.fromData(
                data: data,
                errorCorrectLevel: errorCorrectionLevel,
              )
            : QrCode(
                version,
                errorCorrectionLevel,
              ) {
    // configure and make the QR code data
    try {
      if (version != null) {
        _qr.addData(data);
      }
      _qr.make();
    } catch (ex) {
      if (onError != null) {
        _hasError = true;
        onError(ex);
      }
    }
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  /// the qr code version
  final int version;

  /// the qr code error correction level
  final int errorCorrectionLevel;

  /// the color of the dark squares
  final PdfColor color;

  final QrError onError;

  final bool gapless;

  // our qr code data
  final QrCode _qr;

  bool _hasError = false;

  @override
  void paint(Context context) {
    super.paint(context);

    if (_hasError) {
      return;
    }

    final double shortestSide = box.width < box.height ? box.width : box.height;
    assert(shortestSide > 0);

    context.canvas.setFillColor(color);
    final double squareSize = shortestSide / _qr.moduleCount.toDouble();
    final int pxAdjustValue = gapless ? 1 : 0;
    for (int x = 0; x < _qr.moduleCount; x++) {
      for (int y = 0; y < _qr.moduleCount; y++) {
        if (_qr.isDark(y, x)) {
          context.canvas.drawRect(
            box.left + x * squareSize,
            box.top - (y + 1) * squareSize,
            squareSize + pxAdjustValue,
            squareSize + pxAdjustValue,
          );
        }
      }
    }

    context.canvas.fillPath();
  }
}

class QrCodeWidget extends StatelessWidget {
  QrCodeWidget({
    @required this.data,
    this.version,
    this.errorCorrectionLevel = QrErrorCorrectLevel.L,
    this.color = PdfColors.black,
    this.backgroundColor,
    this.decoration,
    this.margin,
    this.onError,
    this.gapless = false,
    this.size,
    this.padding,
  });

  /// the qr code data
  final String data;

  /// the qr code version
  final int version;

  /// the qr code error correction level
  final int errorCorrectionLevel;

  /// the color of the dark squares
  final PdfColor color;

  final PdfColor backgroundColor;

  final EdgeInsets margin;

  final QrError onError;

  final bool gapless;

  final double size;

  final EdgeInsets padding;

  final BoxDecoration decoration;

  @override
  Widget build(Context context) {
    Widget qrcode = AspectRatio(
        aspectRatio: 1.0,
        child: _QrCodeWidget(
          data: data,
          version: version,
          errorCorrectionLevel: errorCorrectionLevel,
          color: color,
          onError: onError,
          gapless: gapless,
        ));

    if (padding != null) {
      qrcode = Padding(padding: padding, child: qrcode);
    }

    if (decoration != null) {
      qrcode = DecoratedBox(
        decoration: decoration,
        child: qrcode,
      );
    } else if (backgroundColor != null) {
      qrcode = DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor),
        child: qrcode,
      );
    }

    if (size != null) {
      qrcode = SizedBox(width: size, height: size, child: qrcode);
    }

    if (margin != null) {
      qrcode = Padding(padding: margin, child: qrcode);
    }

    return qrcode;
  }
}
