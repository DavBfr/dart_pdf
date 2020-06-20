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

@Deprecated('Use BarcodeWidget instead')
class QrCodeWidget extends StatelessWidget {
  QrCodeWidget({
    @required this.data,
    this.version,
    this.errorCorrectionLevel = BarcodeQRCorrectionLevel.low,
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
  final BarcodeQRCorrectionLevel errorCorrectionLevel;

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
    return BarcodeWidget(
      barcode: Barcode.qrCode(
        typeNumber: version,
        errorCorrectLevel: errorCorrectionLevel,
      ),
      data: data,
      backgroundColor: backgroundColor,
      color: color,
      decoration: decoration,
      width: size,
      height: size,
      margin: margin,
      padding: padding,
    );
  }
}
