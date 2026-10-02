/**
 * Represents a glyph bounding box
 */
class BBox {
  BBox([
    this.minX = double.infinity,
    this.minY = double.infinity,
    this.maxX = double.infinity * -1,
    this.maxY = double.infinity * -1,
  ]);

  num minX = double.infinity;
  num minY = double.infinity;
  num maxX = double.infinity * -1;
  num maxY = double.infinity * -1;

  /**
   * The width of the bounding box
   */
  get width {
    return this.maxX - this.minX;
  }

  /**
   * The height of the bounding box
   */
  get height {
    return this.maxY - this.minY;
  }

  addPoint(num x, num y) {
    if (x.abs() != double.infinity) {
      if (x < this.minX) {
        this.minX = x;
      }

      if (x > this.maxX) {
        this.maxX = x;
      }
    }

    if (y.abs() != double.infinity) {
      if (y < this.minY) {
        this.minY = y;
      }

      if (y > this.maxY) {
        this.maxY = y;
      }
    }
  }

  copy() {
    return BBox(this.minX, this.minY, this.maxX, this.maxY);
  }
}
