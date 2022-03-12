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
import 'dart:convert';

import 'package:flutter/services.dart';

import '../mutex.dart';

/// Application asset manifest.
mixin AssetManifest {
  static final _assets = <String>[];

  static final _mutex = Mutex();

  static bool _ready = false;
  static bool _failed = false;

  /// Does is contains this key?
  static Future<bool> contains(String key) async {
    if (_failed) {
      return false;
    }

    await _mutex.acquire();
    try {
      if (!_ready) {
        try {
          final jsonString = await rootBundle.loadString('AssetManifest.json');
          final jsonData = json.decode(jsonString) as Map<String, dynamic>;
          _assets.addAll(jsonData.keys);
        } catch (e) {
          assert(() {
            // ignore: avoid_print
            print(
                'Error loading AssetManifest.json $e Try to call first:\nWidgetsFlutterBinding.ensureInitialized();');
            return true;
          }());

          rootBundle.evict('AssetManifest.json');
          _failed = true;
          _ready = true;
          return false;
        }
        _ready = true;
      }
    } finally {
      _mutex.release();
    }

    return _assets.contains(key);
  }
}
