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
  PdfRaster(
    int width,
    int height,
    Uint8List pixels,
  ) : super(width, height, true, pixels);

  /// Decode RGBA raw image to dart:ui Image
  Future<ui.Image> toImage() {
    final comp = Completer<ui.Image>();
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
  @override
  Future<Uint8List> toPng() async {
    final image = await toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// Image provider for a [PdfRaster]
class PdfRasterImage extends ImageProvider<PdfRaster> {
  /// Create an ImageProvider from a [PdfRaster]
  PdfRasterImage(this.raster);

  /// The image source
  final PdfRaster raster;

  Future<ImageInfo> _loadAsync() async {
    final uiImage = await raster.toImage();
    return ImageInfo(image: uiImage, scale: 1);
  }

  @override
  ImageStreamCompleter loadBuffer(PdfRaster key, DecoderBufferCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync());
  }

  // Flutter 3.9
  // @override
  // ImageStreamCompleter loadImage(PdfRaster key, ImageDecoderCallback decode) {
  //   return OneFrameImageStreamCompleter(_loadAsync());
  // }

  @override
  Future<PdfRaster> obtainKey(ImageConfiguration configuration) async {
    return raster;
  }
}
