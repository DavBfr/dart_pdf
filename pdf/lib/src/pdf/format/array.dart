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

import 'dart:collection';

import '../color.dart';
import 'base.dart';
import 'dict.dart';
import 'indirect.dart';
import 'name.dart';
import 'num.dart';
import 'object_base.dart';
import 'stream.dart';
import 'string.dart';

class PdfArray<T extends PdfDataType> extends PdfDataType {
  PdfArray([Iterable<T>? values]) {
    if (values != null) {
      this.values.addAll(values);
    }
  }

  static PdfArray<PdfIndirect> fromObjects(List<PdfObjectBase> objects) {
    return PdfArray(objects.map<PdfIndirect>((e) => e.ref()).toList());
  }

  static PdfArray<PdfNum> fromNum(List<num> list) {
    return PdfArray(list.map<PdfNum>((num e) => PdfNum(e)).toList());
  }

  static PdfArray fromColor(PdfColor color) {
    if (color is PdfColorCmyk) {
      return PdfArray.fromNum(<double>[
        color.cyan,
        color.magenta,
        color.yellow,
        color.black,
      ]);
    } else {
      return PdfArray.fromNum(<double>[
        color.red,
        color.green,
        color.blue,
      ]);
    }
  }

  final List<T> values = <T>[];

  void add(T v) {
    values.add(v);
  }

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    if (indent != null) {
      s.putBytes(List<int>.filled(indent, 0x20));
      indent += kIndentSize;
    }
    s.putString('[');
    if (values.isNotEmpty) {
      for (var n = 0; n < values.length; n++) {
        final val = values[n];
        if (indent != null) {
          s.putByte(0x0a);
          if (val is! PdfDict && val is! PdfArray) {
            s.putBytes(List<int>.filled(indent, 0x20));
          }
        } else {
          if (n > 0 &&
              !(val is PdfName ||
                  val is PdfString ||
                  val is PdfArray ||
                  val is PdfDict)) {
            s.putByte(0x20);
          }
        }
        val.output(o, s, indent);
      }
      if (indent != null) {
        s.putByte(0x0a);
      }
    }
    if (indent != null) {
      indent -= kIndentSize;
      s.putBytes(List<int>.filled(indent, 0x20));
    }
    s.putString(']');
  }

  /// Make all values unique, preserving the order
  void uniq() {
    if (values.length <= 1) {
      return;
    }

    // ignore: prefer_collection_literals
    final uniques = LinkedHashMap<T, bool>();
    for (final s in values) {
      uniques[s] = true;
    }
    values.clear();
    values.addAll(uniques.keys);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfArray) {
      return values == other.values;
    }

    return false;
  }

  bool get isEmpty => values.isEmpty;

  bool get isNotEmpty => values.isNotEmpty;

  @override
  int get hashCode => values.hashCode;
}
