import '../glyph/bbox.dart';
import '../glyph_info.dart';
import 'glyph_position.dart';
import 'script.dart';

class GlyphRun {
  GlyphRun(
    this.glyphs,
    dynamic features,
    this.script,
    this.language,
    String? direction,
  ) {
    /**
     * An array of GlyphPosition objects for each glyph in the run
     * @type {GlyphPosition[]}
     */
    this.positions = [];

    /**
     * The direction requested for shaping, as passed in (either ltr or rtl).
     * If `null`, the default direction of the script is used.
     */
    this.direction = direction ?? getDirection(this.script);

    /**
     * The features requested during shaping. This is a combination of user
     * specified features and features chosen by the shaper.
     */
    this.features = {};

    // Convert features to an object
    if (features is List) {
      for (var tag in features) {
        this.features[tag] = true;
      }
    } else if (features is Map<String, bool>) {
      this.features = features;
    }
  }

  String direction = 'ltr';
  String? script;
  String? language;
  List<GlyphInfo> glyphs;
  late Map<String, bool> features;
  late List<GlyphPosition> positions;

  /**
   * The total advance width of the run.
   */
  num get advanceWidth {
    num width = 0;
    for (var position in this.positions) {
      width += position.xAdvance;
    }

    return width;
  }

  /**
   * The total advance height of the run.
   */
  num get advanceHeight {
    num height = 0;
    for (var position in this.positions) {
      height += position.yAdvance;
    }

    return height;
  }

  /**
   * The bounding box containing all glyphs in the run.
   */
  BBox get bbox {
    var bbox = BBox();

    num x = 0;
    num y = 0;
    for (int index = 0; index < this.glyphs.length; index++) {
      var glyph = this.glyphs[index];
      var p = this.positions[index];
      var b = glyph.bbox;

      bbox.addPoint(b.minX + x + p.xOffset, b.minY + y + p.yOffset);
      bbox.addPoint(b.maxX + x + p.xOffset, b.maxY + y + p.yOffset);

      x += p.xAdvance;
      y += p.yAdvance;
    }

    return bbox;
  }
}
