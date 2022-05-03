import '../../priv.dart';
import '../document.dart';
import 'object_dict.dart';

enum PdfPageLabelStyle {
  arabic,
  romanUpper,
  romanLower,
  lettersUpper,
  lettersLower
}

class PdfPageLabel {
  PdfPageLabel(this.prefix, {this.style, this.subsequent});

  PdfPageLabel.arabic({this.prefix, this.subsequent})
      : style = PdfPageLabelStyle.arabic;

  PdfPageLabel.romanUpper({this.prefix, this.subsequent})
      : style = PdfPageLabelStyle.romanUpper;

  PdfPageLabel.romanLower({this.prefix, this.subsequent})
      : style = PdfPageLabelStyle.romanLower;

  PdfPageLabel.lettersUpper({this.prefix, this.subsequent})
      : style = PdfPageLabelStyle.lettersUpper;

  PdfPageLabel.lettersLower({this.prefix, this.subsequent})
      : style = PdfPageLabelStyle.lettersLower;

  final PdfPageLabelStyle? style;
  final String? prefix;
  final int? subsequent;

  PdfDict toDict(PdfObject obj) {
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
    return PdfDict({
      if (s != null) '/S': s,
      if (prefix != null && prefix!.isNotEmpty)
        '/P': PdfSecString.fromString(obj, prefix!),
      if (subsequent != null) '/St': PdfNum(subsequent!)
    });
  }

  String _toRoman(int decimal) {
    const dictionary = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD,',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I'
    };

    assert(decimal > 0 && decimal < 3999,
        'Roman numerals are limited to the inclusive range of 1 to 3999.');

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
    final i = subsequent == null ? index : index + subsequent!;

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
class PdfPageLabels extends PdfObjectDict {
  /// Constructs a Pdf PageLabels object.
  PdfPageLabels(PdfDocument pdfDocument) : super(pdfDocument);

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

    final nums = PdfArray();
    for (final entry in labels.entries) {
      nums.add(PdfNum(entry.key));
      nums.add(entry.value.toDict(this));
    }

    params['/Nums'] = nums;
  }
}
