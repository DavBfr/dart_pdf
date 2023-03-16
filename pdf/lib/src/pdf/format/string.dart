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

import 'dart:convert';
import 'dart:typed_data';

import 'base.dart';
import 'object_base.dart';
import 'stream.dart';

enum PdfStringFormat { binary, literal }

class PdfString extends PdfDataType {
  const PdfString(this.value, [this.format = PdfStringFormat.literal]);

  factory PdfString.fromString(String value) {
    return PdfString(_string(value), PdfStringFormat.literal);
  }

  factory PdfString.fromStream(PdfStream value,
      [PdfStringFormat format = PdfStringFormat.literal]) {
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
    const unicodeReplacementCharacterCodePoint = 0xfffd;
    const unicodeByteZeroMask = 0xff;
    const unicodeByteOneMask = 0xff00;
    const unicodeValidRangeMax = 0x10ffff;
    const unicodePlaneOneMax = 0xffff;
    const unicodeUtf16ReservedLo = 0xd800;
    const unicodeUtf16ReservedHi = 0xdfff;
    const unicodeUtf16Offset = 0x10000;
    const unicodeUtf16SurrogateUnit0Base = 0xd800;
    const unicodeUtf16SurrogateUnit1Base = 0xdc00;
    const unicodeUtf16HiMask = 0xffc00;
    const unicodeUtf16LoMask = 0x3ff;

    final encoding = <int>[];

    void add(int unit) {
      encoding.add((unit & unicodeByteOneMask) >> 8);
      encoding.add(unit & unicodeByteZeroMask);
    }

    for (final unit in str.codeUnits) {
      if ((unit >= 0 && unit < unicodeUtf16ReservedLo) ||
          (unit > unicodeUtf16ReservedHi && unit <= unicodePlaneOneMax)) {
        add(unit);
      } else if (unit > unicodePlaneOneMax && unit <= unicodeValidRangeMax) {
        final base = unit - unicodeUtf16Offset;
        add(unicodeUtf16SurrogateUnit0Base +
            ((base & unicodeUtf16HiMask) >> 10));
        add(unicodeUtf16SurrogateUnit1Base + (base & unicodeUtf16LoMask));
      } else {
        add(unicodeReplacementCharacterCodePoint);
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
      case PdfStringFormat.literal:
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
    PdfObjectBase object,
    String value, [
    PdfStringFormat format = PdfStringFormat.literal,
  ]) {
    return PdfSecString(
      object,
      PdfString._string(value),
      format,
    );
  }

  factory PdfSecString.fromStream(
    PdfObjectBase object,
    PdfStream value, [
    PdfStringFormat format = PdfStringFormat.literal,
  ]) {
    return PdfSecString(
      object,
      value.output(),
      format,
    );
  }

  factory PdfSecString.fromDate(PdfObjectBase object, DateTime date) {
    return PdfSecString(
      object,
      PdfString._date(date),
      PdfStringFormat.literal,
    );
  }

  final PdfObjectBase object;

  @override
  void output(PdfStream s, [int? indent]) {
    if (object.encryptCallback == null) {
      return super.output(s, indent);
    }

    final enc = object.encryptCallback!(value, object);
    _output(s, enc);
  }
}
