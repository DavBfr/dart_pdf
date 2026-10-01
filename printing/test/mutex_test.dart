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

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/src/mutex.dart';

void main() {
  test('only one caller at a time is inside the critical section', () async {
    final mutex = Mutex();
    var inside = 0;
    var maxInside = 0;
    final order = <String>[];

    Future<void> section(String name) async {
      await mutex.acquire();
      order.add(name);
      inside++;
      if (inside > maxInside) {
        maxInside = inside;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inside--;
      mutex.release();
    }

    final a = section('a');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = section('b');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final c = section('c');
    await Future.wait(<Future<void>>[a, b, c]);

    expect(maxInside, 1, reason: 'the mutex must exclude');
    expect(order, <String>['a', 'b', 'c'], reason: 'waiters are served FIFO');
    expect(mutex.locked, isFalse);
  });

  test('the mutex stays held while a woken waiter is inside', () async {
    final mutex = Mutex();
    await mutex.acquire();
    expect(mutex.locked, isTrue);

    var entered = false;
    final waiter = mutex.acquire().then((_) => entered = true);

    mutex.release();
    expect(mutex.locked, isTrue, reason: 'ownership moved, it is still held');
    await waiter;
    expect(entered, isTrue);

    mutex.release();
    expect(mutex.locked, isFalse);
  });

  test('a third caller cannot overtake a waiter that owns the mutex', () async {
    final mutex = Mutex();
    await mutex.acquire();

    var secondIn = false;
    var thirdIn = false;
    final second = mutex.acquire().then((_) => secondIn = true);
    final third = mutex.acquire().then((_) => thirdIn = true);

    mutex.release();
    await second;
    expect(secondIn, isTrue);
    expect(thirdIn, isFalse, reason: 'the third must wait for the second');

    mutex.release();
    await third;
    expect(thirdIn, isTrue);
    mutex.release();
    expect(mutex.locked, isFalse);
  });

  group('protect', () {
    test('releases the mutex when the action throws', () async {
      final mutex = Mutex();

      await expectLater(
        mutex.protect(() => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      // Without this the next caller would wait forever, which is what made a
      // failed pdf.js load brick printing for the rest of the session.
      expect(mutex.locked, isFalse);
      await mutex.protect(() async {}).timeout(const Duration(seconds: 1));
    });

    test('returns the value and releases on success', () async {
      final mutex = Mutex();
      expect(await mutex.protect(() async => 42), 42);
      expect(mutex.locked, isFalse);
    });

    test('serialises concurrent actions', () async {
      final mutex = Mutex();
      final events = <String>[];

      Future<void> action(String name) => mutex.protect(() async {
        events.add('$name-in');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        events.add('$name-out');
      });

      await Future.wait(<Future<void>>[action('a'), action('b')]);

      expect(events, <String>['a-in', 'a-out', 'b-in', 'b-out']);
    });
  });
}
