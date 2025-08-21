// This class uses Harfbuzz and bidi algorithm to shape text and return glyphs from a given font and text

import 'package:bidi/bidi.dart' as bidi;

import '../pdf/font/font_metrics.dart';
import '../pdf/font/ttf_parser.dart';
import '../pdf/obj/font.dart';
import '../pdf/obj/ttffont.dart';
import 'harfbuzz.dart';

extension type GlyphIndex(int index) {}

class ShapingResult {
  ShapingResult(this.glyphs, this.font);

  final List<GlyphIndex> glyphs;
  final PdfTtfFont font;

  PdfFontMetrics get metrics => PdfFontMetrics.append(glyphs.map((g) => font.glyphIndexMetrics(g)));
  List<int> get glyphIndices => glyphs.map((g) => g.index).toList();
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
      String text, PdfFont primaryFont, List<PdfTtfFont> fallbackFonts) {
    final paragraphs = bidi.BidiString.fromLogical(text).paragraphs;
    if (paragraphs.isEmpty) {
      return [];
    }

    final primaryFontSubFamily = _getFontSubFamily(primaryFont);
    final orderedFonts = <PdfFont?>[
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

    final bidiSpans = _BidiSpan.createBidiSpans(text);

    final runeAndFonts = <_RuneAndFont>[];
    for (final span in bidiSpans) {
      for (final rune in span.text.runes) {
        final font = commonFont ??
            orderedFonts.firstWhere((f) => f?.isRuneSupported(rune) != false);
        runeAndFonts.add(font != null
            ? _RuneAndFont(rune, font as PdfTtfFont)
            : _RuneAndFont('?'.runes.first, primaryFont as PdfTtfFont));
        if (font != null) {
          orderedFonts[0] = font;
        }
      }
    }

    final textsAndFonts = <_TextAndFont>[runeAndFonts.first.toTextAndFont()];
    for (final text in runeAndFonts.skip(1)) {
      if (text.font == textsAndFonts.last.font) {
        textsAndFonts.last.addRune(text.rune);
      } else {
        textsAndFonts.add(text.toTextAndFont());
      }
    }

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
          _hb
              .getGlyphInfos(buffer)
              .map((info) => GlyphIndex(info.codepoint))
              .toList(),
          textAndFont.font));

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

class _RuneAndFont {
  _RuneAndFont(this.rune, this.font);

  final int rune;
  final PdfTtfFont font;

  _TextAndFont toTextAndFont() => _TextAndFont(String.fromCharCode(rune), font);
}

class _TextAndFont {
  _TextAndFont(this.text, this.font);

  String text;
  final PdfTtfFont font;

  void addRune(int rune) {
    text += String.fromCharCode(rune);
  }
}

class _BidiSpan {
  const _BidiSpan(this.text, int level) : leftToRight = level % 2 == 0;

  final String text;
  final bool leftToRight;

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;

  @override
  String toString() => 'BidiSpan(text: $text, leftToRight: $leftToRight)';

  static List<_BidiSpan> createBidiSpans(String text) {
    final paragraphs = bidi.BidiString.fromLogical(text).paragraphs;

    final spans = <_BidiSpan>[];

    for (final paragraph in paragraphs) {
      final paragraphSpans = <_BidiSpan>[];
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

        paragraphSpans.add(_BidiSpan(text.substring(start, i), level));
        start = i;
        level = curLevel;
      }

      paragraphSpans
          .add(_BidiSpan(text.substring(start, levels.length), level));

      switch (paragraph.embeddingLevel) {
        case 0:
          spans.addAll(paragraphSpans);
          break;
        default:
          spans.addAll(paragraphSpans.reversed);
          break;
      }
    }

    return spans.toList();
  }
}
