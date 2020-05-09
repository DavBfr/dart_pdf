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
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

/// Loads an image from a Flutter [ui.Image]
/// into a [PdfImage] instance
Future<PdfImage> pdfImageFromImage(
    {@required PdfDocument pdf, @required ui.Image image}) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  return PdfImage(pdf,
      image: bytes.buffer.asUint8List(),
      width: image.width,
      height: image.height);
}

/// Loads an image from a Flutter [ImageProvider]
/// into a [PdfImage] instance
Future<PdfImage> pdfImageFromImageProvider(
    {@required PdfDocument pdf,
    @required ImageProvider image,
    ImageConfiguration configuration,
    ImageErrorListener onError}) async {
  final completer = Completer<PdfImage>();
  final stream = image.resolve(configuration ?? ImageConfiguration.empty);

  ImageStreamListener listener;
  listener = ImageStreamListener((ImageInfo image, bool sync) async {
    final result = await pdfImageFromImage(pdf: pdf, image: image.image);
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    stream.removeListener(listener);
  }, onError: (dynamic exception, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    if (onError != null) {
      onError(exception, stackTrace);
    } else {
      // https://groups.google.com/forum/#!topic/flutter-announce/hp1RNIgej38
      assert(false, 'image failed to load');
    }
  });

  stream.addListener(listener);
  return completer.future;
}

/// Loads a font from an asset bundle key. If used multiple times with the same font name,
/// it will be included multiple times in the pdf file
Future<TtfFont> fontFromAssetBundle(String key, AssetBundle bundle) async {
  final data = await bundle.load(key);
  return TtfFont(data);
}
