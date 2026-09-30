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

import 'base.dart';
import 'object_base.dart';
import 'stream.dart';

class PdfNum extends PdfDataType {
  const PdfNum(this.value)
    : assert(value != double.infinity),
      assert(value != double.negativeInfinity);

  static const int precision = 5;

  final num value;

  /// Formatted doubles, keyed by value.
  ///
  /// A document repeats its geometry constantly — the same tile coordinates,
  /// font sizes and colours recur on every page — and `toStringAsFixed` plus
  /// the string it allocates is one of the most expensive things in a large
  /// document. Cached entries are whatever [_format] produced for that exact
  /// value, so output is unchanged; only the repeated conversion is skipped.
  static final Map<double, String> _formatted = <double, String>{};

  /// Lazily-filled decimal strings for small non-negative ints.
  static final List<String?> _intCache = List<String?>.filled(4096, null);

  /// Bounds the cache for pathological documents whose numbers never repeat.
  /// Real ones settle far below this; past the cap formatting just runs each
  /// time, exactly as it did before.
  static const int _cacheLimit = 1 << 16;

  static String _format(double value) {
    var r = value.toStringAsFixed(precision);
    // Preserved verbatim, including the fact that a value of 1e21 or more
    // formats as exponent notation ('1e+30') where this trim can corrupt the
    // exponent. Reproducing the existing output exactly matters more than
    // fixing that here: these bytes go to a press.
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

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    write(s, value);
  }

  /// Writes [value] to [s] exactly as [output] would, without needing a
  /// [PdfNum] instance. Hot emission paths call this directly so a content
  /// stream full of coordinates does not allocate a wrapper per number.
  static void write(PdfStream s, num value) {
    assert(!value.isNaN);
    assert(!value.isInfinite);

    final v = value;
    if (v is int) {
      // Small ints (object serials aside, almost every int a content stream
      // writes) skip the per-call toString allocation.
      if (v >= 0 && v < _intCache.length) {
        s.putString(_intCache[v] ??= v.toString());
      } else {
        s.putString(v.toString());
      }
      return;
    }

    final d = v.toDouble();

    // Handled before the cache: -0.0 == 0.0 and the two hash alike, so a map
    // would hand back '0' for -0.0 (which formats as '-0').
    if (d == 0) {
      s.putString(d.isNegative ? '-0' : '0');
      return;
    }

    final cached = _formatted[d];
    if (cached != null) {
      s.putString(cached);
      return;
    }

    final formatted = _format(d);
    if (_formatted.length < _cacheLimit) {
      _formatted[d] = formatted;
    }
    s.putString(formatted);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfNum) {
      return value == other.value;
    }

    return false;
  }

  PdfNum operator |(PdfNum other) {
    return PdfNum(value.toInt() | other.value.toInt());
  }

  @override
  int get hashCode => value.hashCode;
}

class PdfNumList extends PdfDataType {
  const PdfNumList(this.values);

  final List<num> values;

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    for (var n = 0; n < values.length; n++) {
      if (n > 0) {
        s.putByte(0x20);
      }
      PdfNum.write(s, values[n]);
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfNumList) {
      return values == other.values;
    }

    return false;
  }

  @override
  int get hashCode => values.hashCode;
}
