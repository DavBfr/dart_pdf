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
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'ascii85.dart';
import 'color.dart';
import 'obj/object.dart';
import 'stream.dart';

const _kIndentSize = 2;

abstract class PdfDataType {
  const PdfDataType();

  void output(PdfStream s, [int? indent]);

  PdfStream _toStream() {
    final s = PdfStream();
    output(s);
    return s;
  }

  @override
  String toString() {
    return String.fromCharCodes(_toStream().output());
  }

  @visibleForTesting
  Uint8List toList() {
    return _toStream().output();
  }
}

class PdfBool extends PdfDataType {
  const PdfBool(this.value);

  final bool value;

  @override
  void output(PdfStream s, [int? indent]) {
    s.putString(value ? 'true' : 'false');
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfBool) {
      return value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => value.hashCode;
}

class PdfNum extends PdfDataType {
  const PdfNum(this.value)
      : assert(value != double.infinity),
        assert(value != double.nan),
        assert(value != double.negativeInfinity);

  static const int precision = 5;

  final num value;

  @override
  void output(PdfStream s, [int? indent]) {
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

enum PdfStringFormat { binary, litteral }

class PdfString extends PdfDataType {
  const PdfString(this.value, [this.format = PdfStringFormat.litteral]);

  factory PdfString.fromString(String value) {
    return PdfString(_string(value), PdfStringFormat.litteral);
  }

  factory PdfString.fromStream(PdfStream value,
      [PdfStringFormat format = PdfStringFormat.litteral]) {
    return PdfString(value.output(), format);
  }

  factory PdfString.fromDate(DateTime date) {
    return PdfString(_date(date));
  }

  final Uint8List value;

  final PdfStringFormat format;

  static Uint8List _string(String value) {
    try {
      return latin1.encode(value);
    } catch (e) {
      return Uint8List.fromList(<int>[0xfe, 0xff] + _encodeUtf16be(value));
    }
  }

  static Uint8List _date(DateTime date) {
    final utcDate = date.toUtc();
    final year = utcDate.year.toString().padLeft(4, '0');
    final month = utcDate.month.toString().padLeft(2, '0');
    final day = utcDate.day.toString().padLeft(2, '0');
    final hour = utcDate.hour.toString().padLeft(2, '0');
    final minute = utcDate.minute.toString().padLeft(2, '0');
    final second = utcDate.second.toString().padLeft(2, '0');
    return _string('D:$year$month$day$hour$minute${second}Z');
  }

  /// Produce a list of UTF-16BE encoded bytes.
  static List<int> _encodeUtf16be(String str) {
    const UNICODE_REPLACEMENT_CHARACTER_CODEPOINT = 0xfffd;
    const UNICODE_BYTE_ZERO_MASK = 0xff;
    const UNICODE_BYTE_ONE_MASK = 0xff00;
    const UNICODE_VALID_RANGE_MAX = 0x10ffff;
    const UNICODE_PLANE_ONE_MAX = 0xffff;
    const UNICODE_UTF16_RESERVED_LO = 0xd800;
    const UNICODE_UTF16_RESERVED_HI = 0xdfff;
    const UNICODE_UTF16_OFFSET = 0x10000;
    const UNICODE_UTF16_SURROGATE_UNIT_0_BASE = 0xd800;
    const UNICODE_UTF16_SURROGATE_UNIT_1_BASE = 0xdc00;
    const UNICODE_UTF16_HI_MASK = 0xffc00;
    const UNICODE_UTF16_LO_MASK = 0x3ff;

    final encoding = <int>[];

    void add(int unit) {
      encoding.add((unit & UNICODE_BYTE_ONE_MASK) >> 8);
      encoding.add(unit & UNICODE_BYTE_ZERO_MASK);
    }

    for (final unit in str.codeUnits) {
      if ((unit >= 0 && unit < UNICODE_UTF16_RESERVED_LO) ||
          (unit > UNICODE_UTF16_RESERVED_HI && unit <= UNICODE_PLANE_ONE_MAX)) {
        add(unit);
      } else if (unit > UNICODE_PLANE_ONE_MAX &&
          unit <= UNICODE_VALID_RANGE_MAX) {
        final base = unit - UNICODE_UTF16_OFFSET;
        add(UNICODE_UTF16_SURROGATE_UNIT_0_BASE +
            ((base & UNICODE_UTF16_HI_MASK) >> 10));
        add(UNICODE_UTF16_SURROGATE_UNIT_1_BASE +
            (base & UNICODE_UTF16_LO_MASK));
      } else {
        add(UNICODE_REPLACEMENT_CHARACTER_CODEPOINT);
      }
    }
    return encoding;
  }

  /// Escape special characters
  /// \ddd Character code ddd (octal)
  void _putTextBytes(PdfStream s, List<int> b) {
    for (final c in b) {
      switch (c) {
        case 0x0a: // \n Line feed (LF)
          s.putByte(0x5c);
          s.putByte(0x6e);
          break;
        case 0x0d: // \r Carriage return (CR)
          s.putByte(0x5c);
          s.putByte(0x72);
          break;
        case 0x09: // \t Horizontal tab (HT)
          s.putByte(0x5c);
          s.putByte(0x74);
          break;
        case 0x08: // \b Backspace (BS)
          s.putByte(0x5c);
          s.putByte(0x62);
          break;
        case 0x0c: // \f Form feed (FF)
          s.putByte(0x5c);
          s.putByte(0x66);
          break;
        case 0x28: // \( Left parenthesis
          s.putByte(0x5c);
          s.putByte(0x28);
          break;
        case 0x29: // \) Right parenthesis
          s.putByte(0x5c);
          s.putByte(0x29);
          break;
        case 0x5c: // \\ Backslash
          s.putByte(0x5c);
          s.putByte(0x5c);
          break;
        default:
          s.putByte(c);
      }
    }
  }

  /// Returns the ASCII/Unicode code unit corresponding to the hexadecimal digit
  /// [digit].
  int _codeUnitForDigit(int digit) =>
      digit < 10 ? digit + 0x30 : digit + 0x61 - 10;

  void _output(PdfStream s, Uint8List value) {
    switch (format) {
      case PdfStringFormat.binary:
        s.putByte(0x3c);
        for (final byte in value) {
          s.putByte(_codeUnitForDigit((byte & 0xF0) >> 4));
          s.putByte(_codeUnitForDigit(byte & 0x0F));
        }
        s.putByte(0x3e);
        break;
      case PdfStringFormat.litteral:
        s.putByte(40);
        _putTextBytes(s, value);
        s.putByte(41);
        break;
    }
  }

  @override
  void output(PdfStream s, [int? indent]) {
    _output(s, value);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfString) {
      return value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => value.hashCode;
}

class PdfSecString extends PdfString {
  const PdfSecString(this.object, Uint8List value,
      [PdfStringFormat format = PdfStringFormat.binary])
      : super(value, format);

  factory PdfSecString.fromString(
    PdfObject object,
    String value, [
    PdfStringFormat format = PdfStringFormat.litteral,
  ]) {
    return PdfSecString(
      object,
      PdfString._string(value),
      format,
    );
  }

  factory PdfSecString.fromStream(
    PdfObject object,
    PdfStream value, [
    PdfStringFormat format = PdfStringFormat.litteral,
  ]) {
    return PdfSecString(
      object,
      value.output(),
      format,
    );
  }

  factory PdfSecString.fromDate(PdfObject object, DateTime date) {
    return PdfSecString(
      object,
      PdfString._date(date),
      PdfStringFormat.litteral,
    );
  }

  final PdfObject object;

  @override
  void output(PdfStream s, [int? indent]) {
    if (object.pdfDocument.encryption == null) {
      return super.output(s, indent);
    }

    final enc = object.pdfDocument.encryption!.encrypt(value, object);
    _output(s, enc);
  }
}

class PdfName extends PdfDataType {
  const PdfName(this.value);

  final String value;

  @override
  void output(PdfStream s, [int? indent]) {
    assert(value[0] == '/');
    final bytes = <int>[];
    for (final c in value.codeUnits) {
      assert(c < 0xff && c > 0x00);

      if (c < 0x21 ||
          c > 0x7E ||
          c == 0x23 ||
          (c == 0x2f && bytes.isNotEmpty) ||
          c == 0x5b ||
          c == 0x5d ||
          c == 0x28 ||
          c == 0x3c ||
          c == 0x3e) {
        bytes.add(0x23);
        final x = c.toRadixString(16).padLeft(2, '0');
        bytes.addAll(x.codeUnits);
      } else {
        bytes.add(c);
      }
    }
    s.putBytes(bytes);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfName) {
      return value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => value.hashCode;
}

class PdfNull extends PdfDataType {
  const PdfNull();

  @override
  void output(PdfStream s, [int? indent]) {
    s.putString('null');
  }

  @override
  bool operator ==(Object other) {
    return other is PdfNull;
  }

  @override
  int get hashCode => null.hashCode;
}

class PdfIndirect extends PdfDataType {
  const PdfIndirect(this.ser, this.gen);

  final int ser;

  final int gen;

  @override
  void output(PdfStream s, [int? indent]) {
    s.putString('$ser $gen R');
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfIndirect) {
      return ser == other.ser && gen == other.gen;
    }

    return false;
  }

  @override
  int get hashCode => ser.hashCode + gen.hashCode;
}

class PdfArray<T extends PdfDataType> extends PdfDataType {
  PdfArray([Iterable<T>? values]) {
    if (values != null) {
      this.values.addAll(values);
    }
  }

  static PdfArray<PdfIndirect> fromObjects(List<PdfObject> objects) {
    return PdfArray(
        objects.map<PdfIndirect>((PdfObject e) => e.ref()).toList());
  }

  static PdfArray<PdfNum> fromNum(List<num> list) {
    return PdfArray(list.map<PdfNum>((num e) => PdfNum(e)).toList());
  }

  final List<T> values = <T>[];

  void add(T v) {
    values.add(v);
  }

  @override
  void output(PdfStream s, [int? indent]) {
    if (indent != null) {
      s.putBytes(List<int>.filled(indent, 0x20));
      indent += _kIndentSize;
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
        val.output(s, indent);
      }
      if (indent != null) {
        s.putByte(0x0a);
      }
    }
    if (indent != null) {
      indent -= _kIndentSize;
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

  @override
  int get hashCode => values.hashCode;
}

class PdfDict<T extends PdfDataType> extends PdfDataType {
  factory PdfDict([Map<String, T>? values]) {
    final _values = <String, T>{};
    if (values != null) {
      _values.addAll(values);
    }
    return PdfDict.values(_values);
  }

  const PdfDict.values([this.values = const {}]);

  static PdfDict<PdfIndirect> fromObjectMap(Map<String, PdfObject> objects) {
    return PdfDict(
      objects.map<String, PdfIndirect>(
        (String key, PdfObject value) =>
            MapEntry<String, PdfIndirect>(key, value.ref()),
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
  void output(PdfStream s, [int? indent]) {
    if (indent != null) {
      s.putBytes(List<int>.filled(indent, 0x20));
    }
    s.putBytes(const <int>[0x3c, 0x3c]);
    var len = 0;
    var n = 1;
    if (indent != null) {
      s.putByte(0x0a);
      indent += _kIndentSize;
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
      v.output(s, indent);
      if (indent != null) {
        s.putByte(0x0a);
      }
    });
    if (indent != null) {
      indent -= _kIndentSize;
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

class PdfDictStream extends PdfDict<PdfDataType> {
  factory PdfDictStream({
    required PdfObject object,
    Map<String, PdfDataType>? values,
    Uint8List? data,
    bool isBinary = false,
    bool encrypt = true,
    bool compress = true,
  }) {
    return PdfDictStream.values(
      object: object,
      values: values ?? {},
      data: data ?? Uint8List(0),
      encrypt: encrypt,
      compress: compress,
      isBinary: isBinary,
    );
  }

  PdfDictStream.values({
    required this.object,
    required Map<String, PdfDataType> values,
    required this.data,
    this.isBinary = false,
    this.encrypt = true,
    this.compress = true,
  }) : super.values(values);

  Uint8List data;

  final PdfObject object;

  final bool isBinary;

  final bool encrypt;

  final bool compress;

  @override
  void output(PdfStream s, [int? indent]) {
    final _values = PdfDict(values);

    Uint8List? _data;

    if (_values.containsKey('/Filter')) {
      // The data is already in the right format
      _data = data;
    } else if (compress && object.pdfDocument.compress) {
      // Compress the data
      final newData = Uint8List.fromList(object.pdfDocument.deflate!(data));
      if (newData.lengthInBytes < data.lengthInBytes) {
        _values['/Filter'] = const PdfName('/FlateDecode');
        _data = newData;
      }
    }

    if (_data == null) {
      if (isBinary) {
        // This is an Ascii85 stream
        final e = Ascii85Encoder();
        _data = e.convert(data);
        _values['/Filter'] = const PdfName('/ASCII85Decode');
      } else {
        // This is a non-deflated stream
        _data = data;
      }
    }

    if (encrypt && object.pdfDocument.encryption != null) {
      _data = object.pdfDocument.encryption!.encrypt(_data, object);
    }

    _values['/Length'] = PdfNum(_data.length);

    _values.output(s, indent);
    if (indent != null) {
      s.putByte(0x0a);
    }
    s.putString('stream\n');
    s.putBytes(_data);
    s.putString('\nendstream\n');
  }
}

class PdfColorType extends PdfDataType {
  const PdfColorType(this.color);

  final PdfColor color;

  @override
  void output(PdfStream s, [int? indent]) {
    if (color is PdfColorCmyk) {
      final k = color as PdfColorCmyk;
      PdfArray.fromNum(<double>[
        k.cyan,
        k.magenta,
        k.yellow,
        k.black,
      ]).output(s, indent);
    } else {
      PdfArray.fromNum(<double>[
        color.red,
        color.green,
        color.blue,
      ]).output(s, indent);
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfColorType) {
      return color == other.color;
    }

    return false;
  }

  @override
  int get hashCode => color.hashCode;
}
