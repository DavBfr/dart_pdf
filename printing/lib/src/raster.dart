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

/// Represents a bitmap image
class PdfRaster {
  /// Create a bitmap image
  PdfRaster(
    this.width,
    this.height,
    this.pixels,
  );

  /// The width of the image
  final int width;

  /// The height of the image
  final int height;

  /// The raw RGBA pixels of the image
  final Uint8List pixels;

  @override
  String toString() => 'Image ${width}x$height ${pixels.lengthInBytes} bytes';

  /// Decode RGBA raw image to dart:ui Image
  Future<ui.Image> toImage() {
    final Completer<ui.Image> comp = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) => comp.complete(image),
    );
    return comp.future;
  }

  /// Convert to a PNG image
  Future<Uint8List> toPng() async {
    final ui.Image image = await toImage();
    final ByteData data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return data.buffer.asUint8List();
  }
}

/// Image provider for a [PdfRaster]
class PdfRasterImage extends ImageProvider<PdfRaster> {
  /// Create an ImageProvider from a [PdfRaster]
  PdfRasterImage(this.raster);

  /// The image source
  final PdfRaster raster;

  Future<ImageInfo> _loadAsync() async {
    final ui.Image uiImage = await raster.toImage();
    return ImageInfo(image: uiImage, scale: 1);
  }

  @override
  ImageStreamCompleter load(PdfRaster key, DecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync());
  }

  @override
  Future<PdfRaster> obtainKey(ImageConfiguration configuration) async {
    return raster;
  }
}
