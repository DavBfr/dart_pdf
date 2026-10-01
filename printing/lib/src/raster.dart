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
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';

/// Represents a bitmap image
class PdfRaster extends PdfRasterBase {
  /// Create a bitmap image
  PdfRaster(int width, int height, Uint8List pixels)
    : super(width, height, true, pixels);

  /// Decode RGBA raw image to dart:ui Image
  Future<ui.Image> toImage() {
    final comp = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      comp.complete,
    );
    return comp.future;
  }

  /// Convert to a PNG image
  @override
  Future<Uint8List> toPng() async {
    final image = await toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// A [PdfRaster] whose bytes are already PNG-encoded by the platform side
/// (e.g. compressed natively right after rendering, instead of shipping a
/// raw ARGB_8888 buffer across the platform channel).
///
/// [toPng] returns the bytes as-is, with no decode/re-encode round trip.
/// Raw pixels are only decoded on demand, if [pixels] or [toImage] is
/// actually used.
class PngPdfRaster extends PdfRaster {
  /// Wrap already PNG-encoded bytes coming from the platform side.
  PngPdfRaster(int width, int height, this.png)
    : super(width, height, Uint8List(0));

  /// The PNG-encoded image data
  final Uint8List png;

  Uint8List? _pixels;

  @override
  Uint8List get pixels {
    _pixels ??= PdfRasterBase.fromPng(png).pixels;
    return _pixels!;
  }

  @override
  Future<ui.Image> toImage() async {
    final codec = await ui.instantiateImageCodec(png);
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  Future<Uint8List> toPng() async => png;
}

/// Image provider for a [PdfRaster]
class PdfRasterImage extends ImageProvider<PdfRaster> {
  /// Create an ImageProvider from a [PdfRaster]
  PdfRasterImage(this.raster);

  /// The image source
  final PdfRaster raster;

  Future<ImageInfo> _loadAsync() async {
    final uiImage = await raster.toImage();
    return ImageInfo(image: uiImage);
  }

  @override
  ImageStreamCompleter loadImage(PdfRaster key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync());
  }

  @override
  Future<PdfRaster> obtainKey(ImageConfiguration configuration) async {
    return raster;
  }
}
