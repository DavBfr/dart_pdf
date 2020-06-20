import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:string_scanner/string_scanner.dart';

const dpi = 72.0;
const px = dpi / PdfPageFormat.inch * PdfPageFormat.point;

void main() {
  // Open self
  final source = File('../test/github_social_preview.dart').readAsStringSync();
  final code = DartSyntaxHighlighter(
    SyntaxHighlighterStyle.dark(),
  ).format(
    source.substring(
      source.lastIndexOf('// START') + 9,
      source.lastIndexOf('// END') - 3,
    ),
  );

  // START
  // Enable debug painting
  Document.debug = true;

  // Create a pdf document
  final pdf = Document(
    title: 'Github Social Preview',
    author: 'David PHAM-VAN',
  );

  // New page
  pdf.addPage(
    Page(
      pageFormat: PdfPageFormat(
        1280 * px,
        640 * px,
        marginAll: 78 * px,
      ),
      build: (context) => Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Display the source code on the first half of the page
          Flexible(
            fit: FlexFit.tight,
            child: Container(
              color: PdfColors.grey800,
              padding: EdgeInsets.all(10 * px),
              child: ClipRect(child: RichText(text: code)),
            ),
          ),
          // Add a vertical separator
          Container(width: 5 * px, color: PdfColors.lightBlue),
          // Show "Hello World!" centered and rotated on the second half of the page
          Flexible(
            fit: FlexFit.tight,
            child: Center(
              child: Transform.rotateBox(
                angle: .2,
                child: Text(
                  'Hello World!',
                  style: TextStyle(
                    font: Font.helveticaBold(),
                    fontSize: 50 * px,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  // END

  // Save the file
  File('social_preview.pdf').writeAsBytesSync(pdf.save());

  // Convert to png
  Process.runSync('pdftocairo',
      ['social_preview.pdf', '-png', '-r', '72', 'social_preview.png']);
}

class SyntaxHighlighterStyle {
  const SyntaxHighlighterStyle(
      {this.baseStyle,
      this.numberStyle,
      this.commentStyle,
      this.keywordStyle,
      this.stringStyle,
      this.punctuationStyle,
      this.classStyle,
      this.constantStyle});

  final TextStyle baseStyle;
  final TextStyle numberStyle;
  final TextStyle commentStyle;
  final TextStyle keywordStyle;
  final TextStyle stringStyle;
  final TextStyle punctuationStyle;
  final TextStyle classStyle;
  final TextStyle constantStyle;

  factory SyntaxHighlighterStyle.dark() => SyntaxHighlighterStyle(
        baseStyle: TextStyle(
          font: Font.courierBold(),
          color: PdfColors.white,
          fontSize: 10 * px,
        ),
        numberStyle: TextStyle(color: PdfColors.purple300),
        commentStyle: TextStyle(color: PdfColors.green600),
        keywordStyle: TextStyle(color: PdfColors.blue600),
        stringStyle: TextStyle(color: PdfColors.orange400),
        punctuationStyle: TextStyle(color: PdfColors.pink),
        classStyle: TextStyle(color: PdfColors.cyan),
        constantStyle: TextStyle(color: PdfColors.pink),
      );
}

class DartSyntaxHighlighter {
  DartSyntaxHighlighter(this._style) {
    _spans = <_HighlightSpan>[];
  }

  final SyntaxHighlighterStyle _style;

  static const List<String> _keywords = <String>[
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'external',
    'extends',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'implements',
    'import',
    'in',
    'is',
    'library',
    'new',
    'null',
    'operator',
    'part',
    'rethrow',
    'return',
    'set',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield'
  ];

  static const List<String> _builtInTypes = <String>[
    'int',
    'double',
    'num',
    'bool'
  ];

  String _src;
  StringScanner _scanner;

  List<_HighlightSpan> _spans;

  TextSpan format(String source) {
    _src = source;

    _scanner = StringScanner(_src);

    if (_generateSpans()) {
      // Successfully parsed the code
      final List<TextSpan> formattedText = <TextSpan>[];
      int currentPosition = 0;

      for (_HighlightSpan span in _spans) {
        if (currentPosition != span.start)
          formattedText
              .add(TextSpan(text: _src.substring(currentPosition, span.start)));

        formattedText.add(TextSpan(
            style: span.textStyle(_style), text: span.textForSpan(_src)));

        currentPosition = span.end;
      }

      if (currentPosition != _src.length)
        formattedText
            .add(TextSpan(text: _src.substring(currentPosition, _src.length)));
      _spans.clear();
      return TextSpan(style: _style.baseStyle, children: formattedText);
    } else {
      // Parsing failed, return with only basic formatting
      return TextSpan(style: _style.baseStyle, text: source);
    }
  }

  bool _generateSpans() {
    int lastLoopPosition = _scanner.position;

    while (!_scanner.isDone) {
      // Skip White space
      _scanner.scan(RegExp(r'\s+'));

      // Block comments
      if (_scanner.scan(RegExp(r'/\*(.|\n)*\*/'))) {
        _spans.add(_HighlightSpan(_HighlightType.comment,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Line comments
      if (_scanner.scan('//')) {
        final int startComment = _scanner.lastMatch.start;

        bool eof = false;
        int endComment;
        if (_scanner.scan(RegExp(r'.*\n'))) {
          endComment = _scanner.lastMatch.end - 1;
        } else {
          eof = true;
          endComment = _src.length;
        }

        _spans.add(
            _HighlightSpan(_HighlightType.comment, startComment, endComment));

        if (eof) {
          break;
        }

        continue;
      }

      // Raw r"String"
      if (_scanner.scan(RegExp(r'r".*"'))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Raw r'String'
      if (_scanner.scan(RegExp(r"r'.*'"))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Multiline """String"""
      if (_scanner.scan(RegExp(r'"""(?:[^"\\]|\\(.|\n))*"""'))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Multiline '''String'''
      if (_scanner.scan(RegExp(r"'''(?:[^'\\]|\\(.|\n))*'''"))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // "String"
      if (_scanner.scan(RegExp(r'"(?:[^"\\]|\\.)*"'))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // 'String'
      if (_scanner.scan(RegExp(r"'(?:[^'\\]|\\.)*'"))) {
        _spans.add(_HighlightSpan(_HighlightType.string,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Double
      if (_scanner.scan(RegExp(r'\d+\.\d+'))) {
        _spans.add(_HighlightSpan(_HighlightType.number,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Integer
      if (_scanner.scan(RegExp(r'\d+'))) {
        _spans.add(_HighlightSpan(_HighlightType.number,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Punctuation
      if (_scanner.scan(RegExp(r'[\[\]{}().!=<>&\|\?\+\-\*/%\^~;:,]'))) {
        _spans.add(_HighlightSpan(_HighlightType.punctuation,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Meta data
      if (_scanner.scan(RegExp(r'@\w+'))) {
        _spans.add(_HighlightSpan(_HighlightType.keyword,
            _scanner.lastMatch.start, _scanner.lastMatch.end));
        continue;
      }

      // Words
      if (_scanner.scan(RegExp(r'\w+'))) {
        _HighlightType type;

        String word = _scanner.lastMatch[0];
        if (word.startsWith('_')) {
          word = word.substring(1);
        }

        if (_keywords.contains(word))
          type = _HighlightType.keyword;
        else if (_builtInTypes.contains(word))
          type = _HighlightType.keyword;
        else if (_firstLetterIsUpperCase(word))
          type = _HighlightType.klass;
        else if (word.length >= 2 &&
            word.startsWith('k') &&
            _firstLetterIsUpperCase(word.substring(1)))
          type = _HighlightType.constant;

        if (type != null) {
          _spans.add(_HighlightSpan(
              type, _scanner.lastMatch.start, _scanner.lastMatch.end));
        }
      }

      // Check if this loop did anything
      if (lastLoopPosition == _scanner.position) {
        // Failed to parse this file, abort gracefully
        return false;
      }
      lastLoopPosition = _scanner.position;
    }

    _simplify();
    return true;
  }

  void _simplify() {
    for (int i = _spans.length - 2; i >= 0; i -= 1) {
      if (_spans[i].type == _spans[i + 1].type &&
          _spans[i].end == _spans[i + 1].start) {
        _spans[i] =
            _HighlightSpan(_spans[i].type, _spans[i].start, _spans[i + 1].end);
        _spans.removeAt(i + 1);
      }
    }
  }

  bool _firstLetterIsUpperCase(String str) {
    if (str.isNotEmpty) {
      final String first = str.substring(0, 1);
      return first == first.toUpperCase();
    }
    return false;
  }
}

enum _HighlightType {
  number,
  comment,
  keyword,
  string,
  punctuation,
  klass,
  constant
}

class _HighlightSpan {
  _HighlightSpan(this.type, this.start, this.end);
  final _HighlightType type;
  final int start;
  final int end;

  String textForSpan(String src) {
    return src.substring(start, end);
  }

  TextStyle textStyle(SyntaxHighlighterStyle style) {
    if (type == _HighlightType.number)
      return style.numberStyle;
    else if (type == _HighlightType.comment)
      return style.commentStyle;
    else if (type == _HighlightType.keyword)
      return style.keywordStyle;
    else if (type == _HighlightType.string)
      return style.stringStyle;
    else if (type == _HighlightType.punctuation)
      return style.punctuationStyle;
    else if (type == _HighlightType.klass)
      return style.classStyle;
    else if (type == _HighlightType.constant)
      return style.constantStyle;
    else
      return style.baseStyle;
  }
}
