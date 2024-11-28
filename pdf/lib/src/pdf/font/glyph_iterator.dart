import 'glyph_info.dart';
import 'gsub_parser.dart';

class GlyphIterator {
  GlyphIterator(this.glyphs, [this.options]) {
    this.reset(this.options);
  }
  final List<GlyphInfo> glyphs;
  LookupFlag? options;
  int index = 0;
  Map<String, bool>? flags;
  int markAttachmentType = 0;

  reset(LookupFlag? options, [int index = 0]) {
    this.options = options;
    this.flags = options?.flags;
    this.markAttachmentType = options?.markAttachmentType ?? 0;
    this.index = index;
  }

  GlyphInfo get cur {
    return this.glyphs[this.index];
  }

  shouldIgnore(GlyphInfo glyph) {
    return this.flags != null &&
        ((this.flags!['ignoreMarks']! && glyph.isMark) ||
            (this.flags!['ignoreBaseGlyphs']! && glyph.isBase) ||
            (this.flags!['ignoreLigatures']! && glyph.isLigature) ||
            (this.markAttachmentType > 0 &&
                glyph.isMark &&
                glyph.markAttachmentType != this.markAttachmentType));
  }

  GlyphInfo? move(int dir) {
    this.index += dir;
    while (0 <= this.index &&
        this.index < this.glyphs.length &&
        this.shouldIgnore(this.glyphs[this.index])) {
      this.index += dir;
    }

    if (0 > this.index || this.index >= this.glyphs.length) {
      return null;
    }

    return this.glyphs[this.index];
  }

  GlyphInfo? next() {
    return this.move(1);
  }

  GlyphInfo? prev() {
    return this.move(-1);
  }

  GlyphInfo peek([int count = 1]) {
    int idx = this.index;
    GlyphInfo res = this.increment(count);
    this.index = idx;
    return res;
  }

  int peekIndex([int count = 1]) {
    int idx = this.index;
    this.increment(count);
    int res = this.index;
    this.index = idx;
    return res;
  }

  GlyphInfo increment([int count = 1]) {
    int dir = count < 0 ? -1 : 1;
    count = count.abs();
    while (count-- > 0) {
      this.move(dir);
    }

    return this.glyphs[this.index];
  }
}
