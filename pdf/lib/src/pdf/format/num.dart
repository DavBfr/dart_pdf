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
  const PdfNum(this.value);

  static const int precision = 5;

  /// The largest magnitude this will write: the largest finite single-precision
  /// float, which is as much as a reader has to cope with.
  static const double _limit = 3.403e38;

  final num value;

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    s.putString(_format(o));
  }

  /// [value] in the only number syntax ISO 32000-1 7.3.3 has: an optional sign,
  /// digits, and at most one decimal point.
  ///
  /// Non-finite values and anything from 1e21 up used to go through
  /// toStringAsFixed, which returns 'NaN', 'Infinity' or exponent notation - none
  /// of which a PDF reader can parse, so it dropped the whole operator or
  /// dictionary entry. Asserts were the only guard, and release builds strip
  /// them.
  String _format(PdfObjectBase o) {
    if (value is int) {
      return value.toInt().toString();
    }

    final v = value.toDouble();

    if (!v.isFinite) {
      assert(() {
        if (o.settings.verbose) {
          // ignore: avoid_print
          print('Cannot write $v as a PDF number; writing 0 instead');
        }
        return true;
      }());

      return '0';
    }

    if (v.abs() >= 1e21) {
      // BigInt rather than toInt, which saturates at the platform word size.
      return BigInt.from(v.clamp(-_limit, _limit)).toString();
    }

    var r = v.toStringAsFixed(precision);
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
      PdfNum(values[n]).output(o, s, indent);
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
