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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';

/// Wrap a Flutter Widget identified by a GlobalKey to a PdfImage.
Future<PdfImage> wrapWidget(
  PdfDocument document, {
  @required GlobalKey key,
  int width,
  int height,
  double pixelRatio = 1.0,
}) async {
  assert(key != null);
  assert(pixelRatio != null && pixelRatio > 0);

  final RenderRepaintBoundary wrappedWidget =
      key.currentContext.findRenderObject();
  ui.Image image = await wrappedWidget.toImage(pixelRatio: pixelRatio);

  image = await _resize(image, width, height);

  final ByteData byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final Uint8List imageData = byteData.buffer.asUint8List();
  return PdfImage(document,
      image: imageData, width: image.width, height: image.height);
}

Future<ui.Image> _resize(
  ui.Image image,
  int width,
  int height,
) async {
  if (width == null && height == null) {
    return image;
  }

  width ??= (height / image.height * image.width).toInt();
  height ??= (width / image.width * image.height).toInt();

  final Completer<ui.Image> ptr = Completer<ui.Image>();
  final Uint8List data =
      (await image.toByteData(format: ui.ImageByteFormat.rawRgba))
          .buffer
          .asUint8List();
  ui.decodeImageFromPixels(
    data,
    image.width,
    image.height,
    ui.PixelFormat.rgba8888,
    (ui.Image result) {
      ptr.complete(result);
    },
    targetWidth: width,
    targetHeight: height,
  );
  return ptr.future;
}
