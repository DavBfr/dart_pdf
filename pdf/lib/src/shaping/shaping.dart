// This class uses Harfbuzz and bidi algorithm to shape text and return glyphs from a given font and text

import 'package:bidi/bidi.dart' as bidi;

import '../pdf/obj/ttffont.dart';
import 'harfbuzz.dart';

extension type GlyphIndex(int index) {}

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

  List<GlyphIndex> shape(PdfTtfFont font, String text) {
    final face = _faces[font.fontName];
    if (face == null) {
      throw Exception('Font is missing');
    }

    final faceFont = _hb.fontCreate(face);

    final output = BidiSpan.createBidiSpans(text)
        .where((span) => span.isNotEmpty)
        .expand((span) => _shapeBidiSpan(faceFont, span))
        .toList();

    _hb.fontDestroy(faceFont);

    return output;
  }

  List<GlyphIndex> _shapeBidiSpan(HarfbuzzFont faceFont, BidiSpan span) {
    final buffer = _hb.bufferCreate();
    _hb.bufferAddString(buffer, span.text);
    _hb.bufferGuessSegmentProperties(buffer);

    _hb.shape(faceFont, buffer);

    final glyphs = _hb
        .getGlyphInfos(buffer)
        .map((info) => GlyphIndex(info.codepoint))
        .toList();

    _hb.bufferDestroy(buffer);

    return glyphs;
  }

  void dispose() {
    for (final face in _faces.values) {
      _hb.faceDestroy(face);
    }
    _faces.clear();
  }
}

class BidiSpan {
  const BidiSpan(this.text, int level) : leftToRight = level % 2 == 0;

  final String text;
  final bool leftToRight;

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => text.isNotEmpty;

  @override
  String toString() => 'BidiSpan(text: $text, leftToRight: $leftToRight)';

  static List<BidiSpan> createBidiSpans(String text) {
    final paragraphs = bidi.BidiString.fromLogical(text).paragraphs;

    final spans = <BidiSpan>[];

    for (final paragraph in paragraphs) {
      final paragraphSpans = <BidiSpan>[];
      final paragraphEmbeddingLevel = paragraph.embeddingLevel;
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

        paragraphSpans.add(BidiSpan(text.substring(start, i), level));
        start = i;
        level = curLevel;
      }

      paragraphSpans.add(BidiSpan(text.substring(start, levels.length), level));

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
