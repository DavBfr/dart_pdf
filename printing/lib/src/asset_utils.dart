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
import 'package:pdf/widgets.dart';

/// Loads an image from a Flutter [ImageProvider]
/// into an [ImageProvider] instance
Future<ImageProvider> flutterImageProvider(
  rdr.ImageProvider image, {
  rdr.ImageConfiguration configuration,
  rdr.ImageErrorListener onError,
}) async {
  final completer = Completer<ImageProvider>();
  final stream = image.resolve(configuration ?? rdr.ImageConfiguration.empty);

  rdr.ImageStreamListener listener;
  listener = rdr.ImageStreamListener((rdr.ImageInfo image, bool sync) async {
    final bytes =
        await image.image.toByteData(format: ui.ImageByteFormat.rawRgba);

    final result = RawImage(
        bytes: bytes.buffer.asUint8List(),
        width: image.image.width,
        height: image.image.height);

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
