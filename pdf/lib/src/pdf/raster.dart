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
  const PdfRasterBase(this.width, this.height, this.alpha, this.pixels);

  factory PdfRasterBase.fromImage(im.Image image) {
    final data = image
        .convert(format: im.Format.uint8, numChannels: 4, noAnimation: true)
        .toUint8List();
    return PdfRasterBase(image.width, image.height, true, data);
  }

  factory PdfRasterBase.fromPng(Uint8List png) {
    final img = im.PngDecoder().decode(png)!;
    return PdfRasterBase.fromImage(img);
  }

  /// How far a shadow bitmap reaches past the box it belongs to, on every side.
  ///
  /// The shape is drawn inflated by [spreadRadius] plus [blurRadius], so that
  /// blurring it by [blurRadius] erodes the soft edge back to the box inflated by
  /// [spreadRadius] and spreads the same distance outward - and one more
  /// [blurRadius] of bitmap holds that outward half. The bitmap used to be only
  /// `spreadRadius` larger than the box and was filled edge to edge, so with the
  /// default spreadRadius of 0 the blur had nowhere to bleed and gave back the
  /// same opaque rectangle: a BoxShadow(blurRadius: 8) painted a hard box.
  static double shadowMargin(double spreadRadius, double blurRadius) =>
      spreadRadius + blurRadius * 2;

  static im.ColorUint8 _shadowColor(PdfColor color) => im.ColorUint8(4)
    ..r = color.red * 255
    ..g = color.green * 255
    ..b = color.blue * 255
    ..a = color.alpha * 255;

  static im.Image _shadowBitmap(
    double width,
    double height,
    double spreadRadius,
    double blurRadius,
  ) => im.Image(
    width: (width + shadowMargin(spreadRadius, blurRadius) * 2).round(),
    height: (height + shadowMargin(spreadRadius, blurRadius) * 2).round(),
    format: im.Format.uint8,
    numChannels: 4,
  );

  static im.Image shadowRect(
    double width,
    double height,
    double spreadRadius,
    double blurRadius,
    PdfColor color,
  ) {
    final shadow = _shadowBitmap(width, height, spreadRadius, blurRadius);
    final inset = blurRadius.round();

    im.fillRect(
      shadow,
      x1: inset,
      y1: inset,
      x2: shadow.width - 1 - inset,
      y2: shadow.height - 1 - inset,
      color: _shadowColor(color),
    );

    return im.gaussianBlur(shadow, radius: blurRadius.round());
  }

  static im.Image shadowEllipse(
    double width,
    double height,
    double spreadRadius,
    double blurRadius,
    PdfColor color,
  ) {
    final shadow = _shadowBitmap(width, height, spreadRadius, blurRadius);
    final inset = blurRadius.round();

    // The image package has fillCircle but no fillEllipse, and a shadow has two
    // radii whenever the box is not square.
    final cx = (shadow.width - 1) / 2;
    final cy = (shadow.height - 1) / 2;
    final rx = cx - inset;
    final ry = cy - inset;
    final fill = _shadowColor(color);

    if (rx > 0 && ry > 0) {
      for (var y = 0; y < shadow.height; y++) {
        final dy = (y - cy) / ry;
        for (var x = 0; x < shadow.width; x++) {
          final dx = (x - cx) / rx;
          if (dx * dx + dy * dy <= 1.0) {
            shadow.setPixel(x, y, fill);
          }
        }
      }
    }

    return im.gaussianBlur(shadow, radius: blurRadius.round());
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
    return im.PngEncoder().encode(img);
  }

  /// Returns the image as an [Image] object from the pub:image library
  im.Image asImage() {
    return im.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      format: im.Format.uint8,
      numChannels: 4,
    );
  }
}
