// This class uses Harfbuzz to shape text and return glyphs from a given font and text
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

    final buffer = _hb.bufferCreate();
    _hb.bufferAddString(buffer, text);
    _hb.bufferGuessSegmentProperties(buffer);

    _hb.shape(faceFont, buffer);

    final infos = _hb.getGlyphInfos(buffer);
    final glyphs = infos.map((info) => GlyphIndex(info.codepoint)).toList();

    _hb.bufferDestroy(buffer);
    _hb.fontDestroy(faceFont);

    return glyphs;
  }

  void dispose() {
    for (final face in _faces.values) {
      _hb.faceDestroy(face);
    }
    _faces.clear();
  }
}
