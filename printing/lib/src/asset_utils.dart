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

import 'package:flutter/rendering.dart' as rdr;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import 'cache.dart';

/// Loads an image from a Flutter [ImageProvider]
/// into an [ImageProvider] instance
Future<ImageProvider> flutterImageProvider(
  rdr.ImageProvider image, {
  rdr.ImageConfiguration? configuration,
  rdr.ImageErrorListener? onError,
}) async {
  final completer = Completer<ImageProvider>();
  final stream = image.resolve(configuration ?? rdr.ImageConfiguration.empty);

  late rdr.ImageStreamListener listener;
  listener = rdr.ImageStreamListener((rdr.ImageInfo image, bool sync) async {
    final bytes =
        await image.image.toByteData(format: ui.ImageByteFormat.rawRgba);

    final result = RawImage(
        bytes: bytes!.buffer.asUint8List(),
        width: image.image.width,
        height: image.image.height);

    if (!completer.isCompleted) {
      completer.complete(result);
    }
    stream.removeListener(listener);
  }, onError: (dynamic exception, StackTrace? stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError('image failed to load');
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
Future<TtfFont> fontFromAssetBundle(
  String key, {
  AssetBundle? bundle,
  bool cache = true,
  PdfBaseCache? pdfCache,
  bool protect = false,
}) async {
  bundle ??= rootBundle;
  final bytes = await bundle.load(key);
  return TtfFont(bytes, protect: protect);
}

/// Load an image from an asset bundle key.
Future<ImageProvider> imageFromAssetBundle(
  String key, {
  AssetBundle? bundle,
  bool cache = true,
  PdfImageOrientation? orientation,
  double? dpi,
  PdfBaseCache? pdfCache,
}) async {
  bundle ??= rootBundle;
  final bytes = await bundle.load(key);

  return MemoryImage(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    orientation: orientation,
    dpi: dpi,
  );
}

/// Download an image from the network.
Future<ImageProvider> networkImage(
  String url, {
  bool cache = true,
  Map<String, String>? headers,
  PdfImageOrientation? orientation,
  double? dpi,
  PdfBaseCache? pdfCache,
}) async {
  pdfCache ??= PdfBaseCache.defaultCache;
  final bytes = await pdfCache.resolve(
    name: url,
    uri: Uri.parse(url),
    cache: cache,
    headers: headers,
  );

  return MemoryImage(bytes, orientation: orientation, dpi: dpi);
}
