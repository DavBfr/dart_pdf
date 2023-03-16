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
import 'stream.dart';

class PdfNum extends PdfDataType {
  const PdfNum(this.value)
      : assert(value != double.infinity),
        assert(value != double.negativeInfinity);

  static const int precision = 5;

  final num value;

  @override
  void output(PdfStream s, [int? indent]) {
    assert(!value.isNaN);
    assert(!value.isInfinite);

    if (value is int) {
      s.putString(value.toInt().toString());
    } else {
      var r = value.toStringAsFixed(precision);
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
      s.putString(r);
    }
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
  void output(PdfStream s, [int? indent]) {
    for (var n = 0; n < values.length; n++) {
      if (n > 0) {
        s.putByte(0x20);
      }
      PdfNum(values[n]).output(s, indent);
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
