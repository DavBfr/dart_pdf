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
  final _waiting = <Completer<void>>[];

  bool _locked = false;

  /// Whether some caller currently owns the mutex
  bool get locked => _locked;

  /// Wait for the mutex to be available
  Future<void> wait() async {
    await acquire();
    release();
  }

  /// Lock the mutex
  ///
  /// The returned future completes when this caller owns the mutex, and no
  /// other caller owns it until [release] is called.
  Future<void> acquire() {
    if (_locked) {
      final c = Completer<void>();
      _waiting.add(c);
      // [release] hands the mutex over already held, so a woken waiter must
      // not set `_locked` again: doing so is what used to let every waiter
      // run at the same time.
      return c.future;
    }
    _locked = true;
    return Future<void>.value();
  }

  /// Release the mutex
  void release() {
    assert(_locked, 'Mutex.release() called while the mutex is not locked');
    if (_waiting.isNotEmpty) {
      // Transfer ownership to the next waiter in arrival order. `_locked`
      // stays true, so nobody can slip in during the microtask in which that
      // waiter resumes.
      _waiting.removeAt(0).complete();
    } else {
      _locked = false;
    }
  }

  /// Run [action] while holding the mutex, releasing it even if [action]
  /// throws.
  Future<T> protect<T>(FutureOr<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}
