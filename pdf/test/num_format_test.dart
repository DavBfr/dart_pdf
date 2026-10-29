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

import 'dart:math';

import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

/// The formatter PdfNum used before it memoised and special-cased zero. Every
/// byte a press sees comes through PdfNum, so the fast path has to be provably
/// identical to this, not merely close.
String reference(num value) {
  if (value is int) {
    return value.toInt().toString();
  }
  var r = value.toStringAsFixed(PdfNum.precision);
  if (r.contains('.')) {
    var n = r.length - 1;
    while (r[n] == '0') {
      n--;
    }
    if (r[n] == '.') {
      n--;
    }
    r = r.substring(0, n + 1);
  }
  return r;
}

String actual(num value) => PdfNum(value).toString();

void expectSame(num value) {
  expect(actual(value), reference(value), reason: 'formatting $value');
}

void main() {
  test('signed zero', () {
    // -0.0 == 0.0 and both hash alike, so a value-keyed cache would collide.
    expect(actual(-0.0), '-0');
    expect(actual(0.0), '0');
    expect(actual(0), '0');
  });

  test('matches the reference formatter on edge cases', () {
    <num>[
      0, 1, -1, 7, -7, 1000000, -1000000,
      0.5, -0.5, 0.1, 0.25, 1.5, -1.5,
      // Rounding at and either side of the 5th decimal.
      0.000005, -0.000005, 0.0000049999, 0.0000050001,
      0.123455, 0.123465, 1.000005, 9.999995,
      // Values that trim to an integer, and ones that keep a fraction.
      2.0, -2.0, 100.0, 2.00001, 2.10000, 2.000001,
      // Below the precision floor, so they trim away entirely.
      1e-6, -1e-6, 1e-9,
      // Large values, including the >= 1e21 exponent-notation range where the
      // reference formatter mangles the exponent. Bug-compatible on purpose.
      1e15, 1e20, 1e21, 1.5e21, 1e30, 2e40, -1e30,
      double.minPositive, -double.minPositive,
      1 / 3, -1 / 3, pi, -pi, e,
    ].forEach(expectSame);
  });

  test('matches the reference formatter across the coordinate range', () {
    // Deterministic sweep over the magnitudes a page actually uses (points on
    // a 500x350mm sheet run to ~1400) plus wider bands either side.
    final rnd = Random(20260730);
    for (final scale in <double>[1e-6, 1e-3, 1, 10, 1400, 1e6, 1e12]) {
      for (var i = 0; i < 200000; i++) {
        final v = (rnd.nextDouble() - 0.5) * 2 * scale;
        expectSame(v);
      }
    }
  });

  test('cache returns the same string as a cold format', () {
    // Second and later calls must agree with the first, and with the
    // reference, for a value seen many times.
    for (final value in <double>[1.23456, 1400.00001, -0.00001, 33.3]) {
      final first = actual(value);
      for (var i = 0; i < 5; i++) {
        expect(actual(value), first);
      }
      expect(first, reference(value));
    }
  });

  test('formatting still matches once the cache is saturated', () {
    // Push well past the cap so the uncached branch is exercised too.
    for (var i = 0; i < 70000; i++) {
      actual(i + 0.00013);
    }
    <double>[0.5, 12.3456, -7.00002, 1e20].forEach(expectSame);
  });
}
