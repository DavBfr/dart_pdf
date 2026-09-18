import 'ot_processor.dart';

class GPOSProcessor extends OTProcessor {
  GPOSProcessor(super.font, super.table);

  applyPositionValue(sequenceIndex, value) {
    var position = this.positions[this.glyphIterator.peekIndex(sequenceIndex)];
    if (value.xAdvance != null) {
      position.xAdvance += value.xAdvance;
    }

    if (value.yAdvance != null) {
      position.yAdvance += value.yAdvance;
    }

    if (value.xPlacement != null) {
      position.xOffset += value.xPlacement;
    }

    if (value.yPlacement != null) {
      position.yOffset += value.yPlacement;
    }

    // Adjustments for font variations
    var variationProcessor = this.font.variationProcessor;
    var variationStore =
        this.font.GDEF != null ? this.font.GDEF.itemVariationStore : null;
    if (variationProcessor && variationStore) {
      if (value.xPlaDevice) {
        position.xOffset += variationProcessor.getDelta(
            variationStore, value.xPlaDevice.a, value.xPlaDevice.b);
      }

      if (value.yPlaDevice) {
        position.yOffset += variationProcessor.getDelta(
            variationStore, value.yPlaDevice.a, value.yPlaDevice.b);
      }

      if (value.xAdvDevice) {
        position.xAdvance += variationProcessor.getDelta(
            variationStore, value.xAdvDevice.a, value.xAdvDevice.b);
      }

      if (value.yAdvDevice) {
        position.yAdvance += variationProcessor.getDelta(
            variationStore, value.yAdvDevice.a, value.yAdvDevice.b);
      }
    }

    // TODO: device tables
  }

  applyLookup(lookupType, table) {
    return false;
  }

  applyAnchor(markRecord, baseAnchor, baseGlyphIndex) {}

  getAnchor(anchor) {
    // TODO: contour point, device tables
    var x = anchor.xCoordinate;
    var y = anchor.yCoordinate;

    // Adjustments for font variations
    var variationProcessor = this.font.variationProcessor;
    var variationStore =
        this.font.GDEF != null ? this.font.GDEF.itemVariationStore : null;
    if (variationProcessor && variationStore) {
      if (anchor.xDeviceTable) {
        x += variationProcessor.getDelta(
            variationStore, anchor.xDeviceTable.a, anchor.xDeviceTable.b);
      }

      if (anchor.yDeviceTable) {
        y += variationProcessor.getDelta(
            variationStore, anchor.yDeviceTable.a, anchor.yDeviceTable.b);
      }
    }

    return {x, y};
  }

  applyFeatures(userFeatures, glyphs, advances) {
    super.applyFeatures(userFeatures, glyphs, advances);

    for (var i = 0; i < this.glyphs.length; i++) {
      this.fixCursiveAttachment(i);
    }

    this.fixMarkAttachment();
  }

  fixCursiveAttachment(i) {
    var glyph = this.glyphs[i];
    if (glyph.cursiveAttachment != null) {
      var j = glyph.cursiveAttachment;

      glyph.cursiveAttachment = null;
      this.fixCursiveAttachment(j);

      this.positions[i].yOffset += this.positions[j].yOffset;
    }
  }

  fixMarkAttachment() {
    for (int i = 0; i < this.glyphs.length; i++) {
      var glyph = this.glyphs[i];
      if (glyph.markAttachment != null) {
        var j = glyph.markAttachment;

        this.positions[i].xOffset += this.positions[j].xOffset;
        this.positions[i].yOffset += this.positions[j].yOffset;

        if (this.direction == 'ltr') {
          for (int k = j; k < i; k++) {
            this.positions[i].xOffset -= this.positions[k].xAdvance;
            this.positions[i].yOffset -= this.positions[k].yAdvance;
          }
        } else {
          for (int k = j + 1; k < i + 1; k++) {
            this.positions[i].xOffset += this.positions[k].xAdvance;
            this.positions[i].yOffset += this.positions[k].yAdvance;
          }
        }
      }
    }
  }
}
