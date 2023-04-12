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

import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

import 'color.dart';

/// Represents a bitmap image
class PdfRasterBase {
  /// Create a bitmap image
  const PdfRasterBase(
    this.width,
    this.height,
    this.alpha,
    this.pixels,
  );

  factory PdfRasterBase.fromImage(im.Image image) {
    final data = image.getBytes(format: im.Format.rgba);
    return PdfRasterBase(image.width, image.height, true, data);
  }

  factory PdfRasterBase.fromPng(Uint8List png) {
    final img = im.PngDecoder().decodeImage(png)!;
    return PdfRasterBase.fromImage(img);
  }

  static im.Image shadowRect(
    double width,
    double height,
    double spreadRadius,
    double blurRadius,
    PdfColor color,
  ) {
    final shadow = im.Image(
      (width + spreadRadius * 2).round(),
      (height + spreadRadius * 2).round(),
    );

    im.fillRect(
      shadow,
      spreadRadius.round(),
      spreadRadius.round(),
      (spreadRadius + width).round(),
      (spreadRadius + height).round(),
      color.toInt(),
    );

    return im.gaussianBlur(shadow, blurRadius.round());
  }

  static im.Image shadowEllipse(
    double width,
    double height,
    double spreadRadius,
    double blurRadius,
    PdfColor color,
  ) {
    final shadow = im.Image(
      (width + spreadRadius * 2).round(),
      (height + spreadRadius * 2).round(),
    );

    im.fillCircle(
      shadow,
      (spreadRadius + width / 2).round(),
      (spreadRadius + height / 2).round(),
      (width / 2).round(),
      color.toInt(),
    );

    return im.gaussianBlur(shadow, blurRadius.round());
  }

  /// The width of the image
  final int width;

  /// The height of the image
  final int height;

  /// The alpha channel is used
  final bool alpha;

  /// The raw RGBA pixels of the image
  final Uint8List pixels;

  @override
  String toString() => 'Image ${width}x$height ${width * height * 4} bytes';

  /// Convert to a PNG image
  Future<Uint8List> toPng() async {
    final img = asImage();
    return Uint8List.fromList(im.PngEncoder().encodeImage(img));
  }

  /// Returns the image as an [Image] object from the pub:image library
  im.Image asImage() {
    return im.Image.fromBytes(
      width,
      height,
      pixels,
    );
  }
}
