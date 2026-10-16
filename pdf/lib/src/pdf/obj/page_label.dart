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

import '../document.dart';
import '../format/array.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../format/num.dart';
import '../format/string.dart';
import 'object.dart';

enum PdfPageLabelStyle {
  arabic,
  romanUpper,
  romanLower,
  lettersUpper,
  lettersLower,
}

class PdfPageLabel {
  PdfPageLabel(this.prefix, {this.style, this.subsequent})
    : assert(_validStart(subsequent), _startMessage);

  PdfPageLabel.arabic({this.prefix, this.subsequent})
    : style = PdfPageLabelStyle.arabic,
      assert(_validStart(subsequent), _startMessage);

  PdfPageLabel.romanUpper({this.prefix, this.subsequent})
    : style = PdfPageLabelStyle.romanUpper,
      assert(_validStart(subsequent), _startMessage);

  PdfPageLabel.romanLower({this.prefix, this.subsequent})
    : style = PdfPageLabelStyle.romanLower,
      assert(_validStart(subsequent), _startMessage);

  PdfPageLabel.lettersUpper({this.prefix, this.subsequent})
    : style = PdfPageLabelStyle.lettersUpper,
      assert(_validStart(subsequent), _startMessage);

  PdfPageLabel.lettersLower({this.prefix, this.subsequent})
    : style = PdfPageLabelStyle.lettersLower,
      assert(_validStart(subsequent), _startMessage);

  /// /St is the number of the first page in the range, so it starts at 1.
  static bool _validStart(int? subsequent) =>
      subsequent == null || subsequent >= 1;

  static const _startMessage =
      'The first page number of a labelling range is at least 1.';

  final PdfPageLabelStyle? style;
  final String? prefix;
  final int? subsequent;

  PdfDict toDict() {
    final PdfName? s;
    switch (style) {
      case PdfPageLabelStyle.arabic:
        s = const PdfName('/D');
        break;
      case PdfPageLabelStyle.romanUpper:
        s = const PdfName('/R');
        break;
      case PdfPageLabelStyle.romanLower:
        s = const PdfName('/r');
        break;
      case PdfPageLabelStyle.lettersUpper:
        s = const PdfName('/A');
        break;
      case PdfPageLabelStyle.lettersLower:
        s = const PdfName('/a');
        break;
      case null:
        s = null;
    }
    return PdfDict.values({
      '/S': ?s,
      if (prefix != null && prefix!.isNotEmpty)
        '/P': PdfString.fromString(prefix!),
      if (subsequent != null) '/St': PdfNum(subsequent!),
    });
  }

  String _toRoman(int decimal) {
    const dictionary = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };

    // Inclusive, as the message says: 3999 is MMMCMXCIX and used to throw with
    // asserts on while working in release.
    assert(
      decimal > 0 && decimal <= 3999,
      'Roman numerals are limited to the inclusive range of 1 to 3999.',
    );

    var result = '';
    dictionary.forEach((k, v) {
      while (decimal >= k) {
        decimal -= k;
        result += v;
      }
    });
    return result;
  }

  String _toLetters(int decimal) {
    final n = String.fromCharCode(0x41 + decimal % 26);
    final r = decimal ~/ 26 + 1;
    return n * r;
  }

  String asString([int index = 0]) {
    // /St defaults to 1 - ISO 32000-1 Table 159 - and the style switch below adds
    // another 1 for arabic and roman, so `index + subsequent` double-counted the
    // first page of every explicit range: arabic(subsequent: 5).asString(0)
    // returned '6'. _toLetters is 0-based and was off by the same one.
    final i = index + (subsequent ?? 1) - 1;

    final String suffix;
    switch (style) {
      case PdfPageLabelStyle.arabic:
        suffix = (i + 1).toString();
        break;
      case PdfPageLabelStyle.romanUpper:
        suffix = _toRoman(i + 1);
        break;
      case PdfPageLabelStyle.romanLower:
        suffix = _toRoman(i + 1).toLowerCase();
        break;
      case PdfPageLabelStyle.lettersUpper:
        suffix = _toLetters(i);
        break;
      case PdfPageLabelStyle.lettersLower:
        suffix = _toLetters(i).toLowerCase();
        break;
      case null:
        suffix = '';
    }
    return '${prefix ?? ''}$suffix';
  }
}

/// Pdf PageLabels object
class PdfPageLabels extends PdfObject<PdfDict> {
  /// Constructs a Pdf PageLabels object.
  PdfPageLabels(PdfDocument pdfDocument)
    : super(pdfDocument, params: PdfDict());

  final labels = <int, PdfPageLabel>{};

  String pageLabel(int index) {
    final n = labels.keys.toList()..sort();
    var current = PdfPageLabel.arabic();
    var s = 0;
    for (final i in n) {
      if (index >= i) {
        current = labels[i]!;
        s = i;
      }
    }

    return current.asString(index - s);
  }

  Iterable<String> get names sync* {
    final n = labels.keys.toList()..sort();
    var l = PdfPageLabel.arabic();
    final len = pdfDocument.pdfPageList.pages.length;
    var c = 0;
    var b = c < n.length ? n[c] : len;
    var s = 0;
    for (var i = 0; i < len; i++) {
      if (i >= b) {
        l = labels[b]!;
        c++;
        b = c < n.length ? n[c] : len;
        s = i;
      }
      yield l.asString(i - s);
    }
  }

  @override
  void prepare() {
    super.prepare();

    // A number tree's keys have to ascend - ISO 32000-1 7.9.7 - and `labels` is a
    // public insertion-ordered map, so writing labels[3] before labels[0] emitted
    // [3 ... 0 ... 1 ...] and a reader that binary-searches the tree lost a whole
    // labelling range. Rebuilt from scratch here, so a second prepare() cannot
    // duplicate anything.
    final keys = labels.keys.toList()..sort();
    final nums = PdfArray();

    // 12.4.2 requires an entry for page index 0. pageLabel and names already
    // report the leading range as plain arabic, so the file now says the same.
    if (keys.isNotEmpty && keys.first != 0) {
      nums.add(const PdfNum(0));
      nums.add(PdfPageLabel.arabic().toDict());
    }

    for (final key in keys) {
      nums.add(PdfNum(key));
      nums.add(labels[key]!.toDict());
    }

    params['/Nums'] = nums;
  }
}
