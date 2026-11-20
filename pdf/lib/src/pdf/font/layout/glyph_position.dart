/**
 * Represents positioning information for a glyph in a GlyphRun.
 */
class GlyphPosition {
  GlyphPosition([xAdvance = 0, yAdvance = 0, xOffset = 0, yOffset = 0]) {
    /**
   * The amount to move the virtual pen in the X direction after rendering this glyph.
   */
    this.xAdvance = xAdvance;

    /**
   * The amount to move the virtual pen in the Y direction after rendering this glyph.
   */
    this.yAdvance = yAdvance;

    /**
   * The offset from the pen position in the X direction at which to render this glyph.
   */
    this.xOffset = xOffset;

    /**
   * The offset from the pen position in the Y direction at which to render this glyph.
   */
    this.yOffset = yOffset;
  }

  num xAdvance = 0;
  num yAdvance = 0;
  num xOffset = 0;
  num yOffset = 0;
}
