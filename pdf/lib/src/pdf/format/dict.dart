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

import 'dart:math' as math;

import 'array.dart';
import 'base.dart';
import 'bool.dart';
import 'indirect.dart';
import 'null_value.dart';
import 'num.dart';
import 'object_base.dart';
import 'stream.dart';

class PdfDict<T extends PdfDataType> extends PdfDataType {
  factory PdfDict([Map<String, T>? values]) {
    final _values = <String, T>{};
    if (values != null) {
      _values.addAll(values);
    }
    return PdfDict.values(_values);
  }

  const PdfDict.values([this.values = const {}]);

  static PdfDict<PdfIndirect> fromObjectMap(
      Map<String, PdfObjectBase> objects) {
    return PdfDict(
      objects.map<String, PdfIndirect>(
        (key, value) => MapEntry<String, PdfIndirect>(key, value.ref()),
      ),
    );
  }

  final Map<String, T> values;

  bool get isNotEmpty => values.isNotEmpty;

  operator []=(String k, T v) {
    values[k] = v;
  }

  T? operator [](String k) {
    return values[k];
  }

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    if (indent != null) {
      s.putBytes(List<int>.filled(indent, 0x20));
    }
    s.putBytes(const <int>[0x3c, 0x3c]);
    var len = 0;
    var n = 1;
    if (indent != null) {
      s.putByte(0x0a);
      indent += kIndentSize;
      len = values.keys.fold<int>(0, (p, e) => math.max(p, e.length));
    }
    values.forEach((String k, T v) {
      if (indent != null) {
        s.putBytes(List<int>.filled(indent, 0x20));
        n = len - k.length + 1;
      }
      s.putString(k);
      if (indent != null) {
        if (v is PdfDict || v is PdfArray) {
          s.putByte(0x0a);
        } else {
          s.putBytes(List<int>.filled(n, 0x20));
        }
      } else {
        if (v is PdfNum || v is PdfBool || v is PdfNull || v is PdfIndirect) {
          s.putByte(0x20);
        }
      }
      v.output(o, s, indent);
      if (indent != null) {
        s.putByte(0x0a);
      }
    });
    if (indent != null) {
      indent -= kIndentSize;
      s.putBytes(List<int>.filled(indent, 0x20));
    }
    s.putBytes(const <int>[0x3e, 0x3e]);
  }

  bool containsKey(String key) {
    return values.containsKey(key);
  }

  void merge(PdfDict<T> other) {
    for (final key in other.values.keys) {
      final value = other[key]!;
      final current = values[key];
      if (current == null) {
        values[key] = value;
      } else if (value is PdfArray && current is PdfArray) {
        current.values.addAll(value.values);
        current.uniq();
      } else if (value is PdfDict && current is PdfDict) {
        current.merge(value);
      } else {
        values[key] = value;
      }
    }
  }

  void addAll(PdfDict<T> other) {
    values.addAll(other.values);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfDict) {
      return values == other.values;
    }

    return false;
  }

  @override
  int get hashCode => values.hashCode;
}
