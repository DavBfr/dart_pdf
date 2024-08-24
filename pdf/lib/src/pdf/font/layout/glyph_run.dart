import '../glyph_info.dart';

class GlyphRun {
  GlyphRun(
    this.glyphs,
    this.features,
    this.script,
    this.language,
    this.direction,
  ) {}
  String direction = 'ltr';
  String? script;
  String? language;
  final List<GlyphInfo> glyphs;
  dynamic features;
}
