// This class uses Harfbuzz and bidi algorithm to shape text and return glyphs from a given font and text

import 'package:bidi/bidi.dart' as bidi;

import '../pdf/font/font_metrics.dart';
import '../pdf/font/ttf_parser.dart';
import '../pdf/obj/font.dart';
import '../pdf/obj/ttffont.dart';
import 'harfbuzz.dart';

extension type GlyphIndex(int index) {}

class ShapingResult {
  ShapingResult(this.text, this.font, this.glyphs);

  String text;
  final PdfTtfFont font;
  final List<GlyphIndex> glyphs;

  PdfFontMetrics get metrics =>
      PdfFontMetrics.append(glyphs.map((g) => font.glyphIndexMetrics(g)));
  List<int> get glyphIndices => glyphs.map((g) => g.index).toList();

  @override
  String toString() =>
      'ShapingResult(text: ` $text `, font: ${font.fontName}, glyphs: $glyphs)';
}

class Shaping {
  factory Shaping() => _instance;

  // Singleton stuff
  Shaping._();
  static final Shaping _instance = Shaping._();

  final Map<String, HarfbuzzFace> _faces = {};
  final HarfbuzzBinding _hb = HarfbuzzBinding();

  void addFont(PdfTtfFont font) {
    _faces[font.fontName] = _hb.faceFromData(font.font.bytes, 0);
  }

  List<ShapingResult> shape(
      String text, PdfTtfFont primaryFont, List<PdfTtfFont> fallbackFonts) {
    for (final font in [primaryFont, ...fallbackFonts]) {
      if (_faces.containsKey(font.fontName)) continue;
      addFont(font);
    }

    final paragraphs = bidi.BidiString.fromLogical(text).paragraphs;
    if (paragraphs.isEmpty) {
      return [];
    }

    final primaryFontSubFamily = _getFontSubFamily(primaryFont);
    final orderedFonts = <PdfTtfFont?>[
      primaryFont,
      primaryFont,
      ...fallbackFonts
          .where((f) => _getFontSubFamily(f) == primaryFontSubFamily),
      ...fallbackFonts
          .where((f) => _getFontSubFamily(f) != primaryFontSubFamily),
      null
    ];

    // Is there a font that supports all runes?
    // Skip first one because it's given twice in the ordered fonts
    final commonFont = orderedFonts.skip(1).firstWhere(
        (f) => text.runes.every((rune) => f?.isRuneSupported(rune) == true),
        orElse: () => null);

    final bidiSpans = BidiSpan.createBidiSpans(text);

    final runeAndFonts = <_RunesAndFont>[];
    for (final span in bidiSpans) {
      final spanRuneAndFonts = <_RunesAndFont>[];
      for (var rune in span.text.runes) {
        var font = commonFont ??
            orderedFonts.firstWhere((f) => f?.isRuneSupported(rune) != false);
        if (font != null) {
          orderedFonts[1] = font;
        }
        if (font == null) {
          rune = '?'.runes.first;
          font = primaryFont;
        }

        if (spanRuneAndFonts.isEmpty || font != spanRuneAndFonts.last.font) {
          spanRuneAndFonts
              .add(_RunesAndFont([rune], font, leftToRight: span.leftToRight));
        } else {
          spanRuneAndFonts.last.runes.add(rune);
        }
      }
      runeAndFonts.addAll(spanRuneAndFonts);
    }

    final textsAndFonts =
        runeAndFonts.map((raf) => raf.toTextAndFont()).toList();

    _reverseLtrSpans(textsAndFonts);

    final output = <ShapingResult>[];

    for (final textAndFont in textsAndFonts) {
      final face = Shaping._instance._faces[textAndFont.font.fontName];
      if (face == null) {
        throw Exception('Font is missing');
      }

      final faceFont = _hb.fontCreate(face);
      final buffer = _hb.bufferCreate();

      _hb.bufferAddString(buffer, textAndFont.text);
      _hb.bufferGuessSegmentProperties(buffer);

      _hb.shape(faceFont, buffer);

      output.add(ShapingResult(
        textAndFont.text,
        textAndFont.font,
        _hb
            .getGlyphInfos(buffer)
            .map((info) => GlyphIndex(info.codepoint))
            .toList(),
      ));

      _hb.bufferDestroy(buffer);
      _hb.fontDestroy(faceFont);
    }

    return output;
  }

  void dispose() {
    for (final face in _faces.values) {
      _hb.faceDestroy(face);
    }
    _faces.clear();
  }
}

String _getFontSubFamily(PdfFont font) {
  if (font is PdfTtfFont) {
    return font.font
            .getNameID(TtfParserName.fontSubfamily)
            ?.toLowerCase()
            .trim() ??
        'regular';
  }
  final name = font.fontName;
  if (name.endsWith('-Bold')) {
    return 'bold';
  }
  return 'regular';
}

class _RunesAndFont {
  _RunesAndFont(this.runes, this.font, {required this.leftToRight});

  final List<int> runes;
  final PdfTtfFont font;
  final bool leftToRight;

  _TextAndFont toTextAndFont() =>
      _TextAndFont(String.fromCharCodes(runes), font, leftToRight: leftToRight);

  @override
  String toString() =>
      'RuneAndFont(font: ${font.fontName}, LTR: $leftToRight, runes: $runes)';
}

class _TextAndFont {
  _TextAndFont(this.text, this.font, {required this.leftToRight});

  String text;
  final PdfTtfFont font;
  final bool leftToRight;

  void addRune(int rune) {
    text += String.fromCharCode(rune);
  }

  @override
  String toString() =>
      'TextAndFont(font: ${font.fontName}, LTR: $leftToRight, text: ` $text ` )';
}

void _reverseLtrSpans(List<_TextAndFont> items) {
  final newItems = <_TextAndFont>[];

  while (items.isNotEmpty) {
    final newItemsSizeLength = newItems.length;
    newItems.addAll(items.takeWhile((item) => item.leftToRight));
    newItems
        .addAll(items.takeWhile((item) => !item.leftToRight).toList().reversed);
    items.removeRange(0, newItems.length - newItemsSizeLength);
  }

  items.addAll(newItems);
}

class BidiSpan {
  const BidiSpan(this.text, int level) : leftToRight = level % 2 == 0;

  final String text;
  final bool leftToRight;

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;

  @override
  String toString() => 'BidiSpan(text: ` $text `  , leftToRight: $leftToRight)';

  static List<BidiSpan> createBidiSpans(String text) {
    final paragraphs = bidi.BidiString.fromLogical(text).paragraphs;

    final spans = <BidiSpan>[];

    for (final paragraph in paragraphs) {
      final paragraphText = String.fromCharCodes(paragraph.text);
      final paragraphSpans = <BidiSpan>[];
      final levels = paragraph.embeddingLevels;
      if (levels.isEmpty) {
        continue;
      }

      var start = 0;
      var level = levels.first;

      for (var i = 1; i < levels.length; i++) {
        final curLevel = levels[i];
        if (level == curLevel) {
          continue;
        }

        paragraphSpans.add(BidiSpan(paragraphText.substring(start, i), level));
        start = i;
        level = curLevel;
      }

      paragraphSpans
          .add(BidiSpan(paragraphText.substring(start, levels.length), level));

      spans.addAll(paragraphSpans);
    }

    return spans.toList();
  }
}
