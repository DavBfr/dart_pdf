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
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' as rdr;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
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
Future<TtfFont> fontFromAssetBundle(String key, [AssetBundle bundle]) async {
  bundle ??= rootBundle;
  final data = await bundle.load(key);
  return TtfFont(data);
}

/// Load an image from an asset bundle key.
Future<ImageProvider> imageFromAssetBundle(String key,
    [AssetBundle bundle]) async {
  bundle ??= rootBundle;
  final data = await bundle.load(key);
  return MemoryImage(data.buffer.asUint8List());
}

final HttpClient _sharedHttpClient = HttpClient();

/// Store network images in a cache
abstract class PdfBaseImageCache {
  /// Create a network image cache
  const PdfBaseImageCache();

  /// The default cache used when none specified
  static final defaultCache = PdfMemoryImageCache();

  /// Add an image to the cache
  Future<void> add(String key, Uint8List bytes);

  /// Retrieve an image from the cache
  Future<Uint8List> get(String key);

  /// Does the cache contains this image?
  Future<bool> contains(String key);

  /// Remove an image from the cache
  Future<void> remove(String key);

  /// Clear the cache
  Future<void> clear();
}

/// Memory image cache
class PdfMemoryImageCache extends PdfBaseImageCache {
  /// Create a memory image cache
  PdfMemoryImageCache();

  final _imageCache = <String, Uint8List>{};

  @override
  Future<void> add(String key, Uint8List bytes) async {
    _imageCache[key] = bytes;
  }

  @override
  Future<Uint8List> get(String key) async {
    return _imageCache[key];
  }

  @override
  Future<void> clear() async {
    _imageCache.clear();
  }

  @override
  Future<bool> contains(String key) async {
    return _imageCache.containsKey(key);
  }

  @override
  Future<void> remove(String key) async {
    _imageCache.remove(key);
  }
}

/// Download an image from the network.
Future<ImageProvider> networkImage(
  String url, {
  bool cache = true,
  Map<String, String> headers,
  PdfImageOrientation orientation,
  double dpi,
  PdfBaseImageCache imageCache,
}) async {
  imageCache ??= PdfBaseImageCache.defaultCache;

  if (cache && await imageCache.contains(url)) {
    return MemoryImage(await imageCache.get(url),
        orientation: orientation, dpi: dpi);
  }

  final request = await _sharedHttpClient.getUrl(Uri.parse(url));
  headers?.forEach((String name, String value) {
    request.headers.add(name, value);
  });
  final response = await request.close();
  final builder = await response.fold(
      BytesBuilder(), (BytesBuilder b, List<int> d) => b..add(d));
  final List<int> data = builder.takeBytes();
  final bytes = Uint8List.fromList(data);

  if (cache) {
    await imageCache.add(url, bytes);
  }

  return MemoryImage(bytes, orientation: orientation, dpi: dpi);
}
