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

/// Simple Mutex
class Mutex {
  final _waiting = <Completer>[];

  bool _locked = false;

  bool get locked => _locked;

  /// Wait for the mutex to be available
  Future<void> wait() async {
    await acquire();
    release();
  }

  /// Lock the mutex
  Future<void> acquire() async {
    if (_locked) {
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
    }
    _locked = true;
  }

  /// Release the mutex
  void release() {
    _locked = false;
    for (final e in _waiting) {
      e.complete();
    }
    _waiting.clear();
  }
}
