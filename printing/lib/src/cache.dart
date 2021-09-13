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

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Store data in a cache
abstract class PdfBaseCache {
  /// Create a cache
  const PdfBaseCache();

  /// The default cache used when none specified
  static PdfBaseCache defaultCache = PdfMemoryCache();

  /// Add some data to the cache
  Future<void> add(String key, Uint8List bytes);

  /// Retrieve some data from the cache
  Future<Uint8List?> get(String key);

  /// Does the cache contains this data?
  Future<bool> contains(String key);

  /// Remove some data from the cache
  Future<void> remove(String key);

  /// Clear the cache
  Future<void> clear();

  /// Download the font
  Future<Uint8List?> _download(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      return null;
    }

    return response.bodyBytes;
  }

  /// Resolve the data
  Future<Uint8List> resolve({
    required String name,
    required Uri uri,
    bool cache = true,
    Map<String, String>? headers,
  }) async {
    if (cache && await contains(name)) {
      return (await get(name))!;
    }

    final bytes = await _download(uri, headers: headers);

    if (bytes == null) {
      throw FlutterError('Unable to download $uri');
    }

    if (cache) {
      await add(name, bytes);
    }

    return bytes;
  }
}

/// Memory cache
class PdfMemoryCache extends PdfBaseCache {
  /// Create a memory cache
  PdfMemoryCache();

  final _imageCache = <String, Uint8List>{};

  Timer? _timer;

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 20), () {
      clear();
    });
  }

  @override
  Future<void> add(String key, Uint8List bytes) async {
    _imageCache[key] = bytes;
    _resetTimer();
  }

  @override
  Future<Uint8List?> get(String key) async {
    _resetTimer();
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

/// Store network images in a cache
@Deprecated('Use PdfBaseCache instead')
abstract class PdfBaseImageCache extends PdfBaseCache {
  /// Create a network image cache
  const PdfBaseImageCache();

  /// The default cache used when none specified
  static final defaultCache = PdfBaseCache.defaultCache;
}

/// Memory image cache
@Deprecated('Use PdfMemoryCache instead')
class PdfMemoryImageCache extends PdfMemoryCache {
  /// Create a memory image cache
  PdfMemoryImageCache();
}
