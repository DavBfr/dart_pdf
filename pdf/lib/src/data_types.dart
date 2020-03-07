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

// ignore_for_file: omit_local_variable_types
// ignore_for_file: avoid_unused_constructor_parameters

part of pdf;

abstract class PdfDataType {
  const PdfDataType();

  void output(PdfStream s);

  PdfStream toStream() {
    final PdfStream s = PdfStream();
    output(s);
    return s;
  }

  @override
  String toString() {
    return String.fromCharCodes(toStream().output());
  }

  List<int> toList() {
    return toStream().output();
  }
}

class PdfBool extends PdfDataType {
  const PdfBool(this.value);

  final bool value;

  @override
  void output(PdfStream s) {
    s.putString(value ? 'true' : 'false');
  }
}

class PdfNum extends PdfDataType {
  const PdfNum(this.value);

  final num value;

  @override
  void output(PdfStream s) {
    if (value is int) {
      s.putString(value.toInt().toString());
    } else {
      s.putNum(value);
    }
  }
}

enum PdfStringFormat { binary, litteral }

class PdfString extends PdfDataType {
  const PdfString(this.value, [this.format = PdfStringFormat.litteral]);

  factory PdfString.fromString(String value) {
    try {
      return PdfString(latin1.encode(value), PdfStringFormat.litteral);
    } catch (e) {
      return PdfString(
        Uint8List.fromList(<int>[0xfe, 0xff] + encodeUtf16be(value)),
        PdfStringFormat.litteral,
      );
    }
  }

  factory PdfString.fromDate(DateTime date) {
    final DateTime utcDate = date.toUtc();
    final String year = utcDate.year.toString().padLeft(4, '0');
    final String month = utcDate.month.toString().padLeft(2, '0');
    final String day = utcDate.day.toString().padLeft(2, '0');
    final String hour = utcDate.hour.toString().padLeft(2, '0');
    final String minute = utcDate.minute.toString().padLeft(2, '0');
    final String second = utcDate.second.toString().padLeft(2, '0');
    return PdfString.fromString('D:$year$month$day$hour$minute${second}Z');
  }

  final Uint8List value;

  final PdfStringFormat format;

  /// Returns the ASCII/Unicode code unit corresponding to the hexadecimal digit
  /// [digit].
  int _codeUnitForDigit(int digit) =>
      digit < 10 ? digit + 0x30 : digit + 0x61 - 10;

  @override
  void output(PdfStream s) {
    switch (format) {
      case PdfStringFormat.binary:
        s.putByte(0x3c);
        for (int byte in value) {
          s.putByte(_codeUnitForDigit((byte & 0xF0) >> 4));
          s.putByte(_codeUnitForDigit(byte & 0x0F));
        }
        s.putByte(0x3e);

        break;
      case PdfStringFormat.litteral:
        s.putByte(40);
        s.putTextBytes(value);
        s.putByte(41);
        break;
    }
  }
}

class PdfSecString extends PdfString {
  const PdfSecString(this.object, Uint8List value,
      [PdfStringFormat format = PdfStringFormat.binary])
      : super(value, format);

  factory PdfSecString.fromString(PdfObject object, String value) {
    try {
      return PdfSecString(
          object, latin1.encode(value), PdfStringFormat.litteral);
    } catch (e) {
      return PdfSecString(
        object,
        Uint8List.fromList(<int>[0xfe, 0xff] + encodeUtf16be(value)),
        PdfStringFormat.litteral,
      );
    }
  }

  factory PdfSecString.fromDate(PdfObject object, DateTime date) {
    final DateTime utcDate = date.toUtc();
    final String year = utcDate.year.toString().padLeft(4, '0');
    final String month = utcDate.month.toString().padLeft(2, '0');
    final String day = utcDate.day.toString().padLeft(2, '0');
    final String hour = utcDate.hour.toString().padLeft(2, '0');
    final String minute = utcDate.minute.toString().padLeft(2, '0');
    final String second = utcDate.second.toString().padLeft(2, '0');
    return PdfSecString.fromString(
        object, 'D:$year$month$day$hour$minute${second}Z');
  }

  final PdfObject object;

  @override
  void output(PdfStream s) {
    if (object.pdfDocument.encryption == null) {
      return super.output(s);
    }

    final List<int> enc = object.pdfDocument.encryption.encrypt(value, object);
    switch (format) {
      case PdfStringFormat.binary:
        s.putByte(0x3c);
        for (int byte in enc) {
          s.putByte(_codeUnitForDigit((byte & 0xF0) >> 4));
          s.putByte(_codeUnitForDigit(byte & 0x0F));
        }
        s.putByte(0x3e);

        break;
      case PdfStringFormat.litteral:
        s.putByte(40);
        s.putTextBytes(enc);
        s.putByte(41);
        break;
    }
  }
}

class PdfName extends PdfDataType {
  const PdfName(this.value);

  final String value;

  @override
  void output(PdfStream s) {
    assert(value[0] == '/');
    s.putString(value);
  }
}

class PdfNull extends PdfDataType {
  const PdfNull();

  @override
  void output(PdfStream s) {
    s.putString('null');
  }
}

class PdfIndirect extends PdfDataType {
  const PdfIndirect(this.ser, this.gen);

  final int ser;

  final int gen;

  @override
  void output(PdfStream s) {
    s.putString('$ser $gen R');
  }
}

class PdfArray extends PdfDataType {
  PdfArray([Iterable<PdfDataType> values]) {
    if (values != null) {
      this.values.addAll(values);
    }
  }

  factory PdfArray.fromObjects(List<PdfObject> objects) {
    return PdfArray(
        objects.map<PdfIndirect>((PdfObject e) => e.ref()).toList());
  }

  factory PdfArray.fromNum(List<num> list) {
    return PdfArray(list.map<PdfNum>((num e) => PdfNum(e)).toList());
  }

  // factory PdfArray.fromStrings(List<String> list) {
  //   return PdfArray(
  //       list.map<PdfString>((String e) => PdfString.fromString(e)).toList());
  // }

  final List<PdfDataType> values = <PdfDataType>[];

  void add(PdfDataType v) {
    values.add(v);
  }

  @override
  void output(PdfStream s) {
    s.putString('[');
    if (values.isNotEmpty) {
      for (int n = 0; n < values.length - 1; n++) {
        final PdfDataType val = values[n];
        val.output(s);
        s.putString(' ');
      }
      values.last.output(s);
    }
    s.putString(']');
  }
}

class PdfDict extends PdfDataType {
  PdfDict([Map<String, PdfDataType> values]) {
    if (values != null) {
      this.values.addAll(values);
    }
  }

  factory PdfDict.fromObjectMap(Map<String, PdfObject> objects) {
    return PdfDict(
      objects.map<String, PdfIndirect>(
        (String key, PdfObject value) =>
            MapEntry<String, PdfIndirect>(key, value.ref()),
      ),
    );
  }

  final Map<String, PdfDataType> values = <String, PdfDataType>{};

  bool get isNotEmpty => values.isNotEmpty;

  operator []=(String k, PdfDataType v) {
    values[k] = v;
  }

  @override
  void output(PdfStream s) {
    s.putString('<< ');
    values.forEach((String k, PdfDataType v) {
      s.putString('$k ');
      v.output(s);
      s.putString('\n');
    });
    s.putString('>>');
  }

  bool containsKey(String key) {
    return values.containsKey(key);
  }
}
