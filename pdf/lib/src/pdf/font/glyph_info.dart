import 'glyph/bbox.dart';
import 'ot_processor.dart';
import 'ttf_parser.dart';

bool checkMark(int code) {
  return false;
}

class GlyphInfo {
  GlyphInfo(this.font, int id, [List<int>? codePoints, dynamic features]) {
    this.id = id;
    this.codePoints = codePoints ?? [];
    this.features = {};
    if (features is List<String>) {
      for (int i = 0; i < features.length; i++) {
        var feature = features[i];
        this.features[feature] = true;
      }
    } else if (features is Map<String, bool>) {
      this.features = {...features};
    }

    this.ligatureID = null;
    this.ligatureComponent = null;
    this.cursiveAttachment = null;
    this.markAttachment = null;
    this.shaperInfo = null;
  }
  final TtfParser font;
  int _id = 0;
  late List<int> codePoints;
  late Map<String, bool> features;
  bool isMultiplied = false;
  bool substituted = false;
  bool isLigated = false;
  bool isMark = false;
  bool isLigature = false;
  bool isBase = false;
  int markAttachmentType = 0;
  BBox bbox = BBox();

  dynamic ligatureID;
  dynamic ligatureComponent;
  dynamic markAttachment;
  dynamic cursiveAttachment;
  dynamic shaperInfo;

  int get id {
    return this._id;
  }

  set id(int val) {
    this._id = val;
    this.substituted = true;
    var GDEF = this.font.GDEF;
    if (GDEF != null && GDEF.glyphClassDef) {
      // TODO: clean this up
      var classID = OTProcessor.getClassID(id, GDEF.glyphClassDef);
      this.isBase = classID == 1;
      this.isLigature = classID == 2;
      this.isMark = classID == 3;
      this.markAttachmentType = GDEF.markAttachClassDef
          ? OTProcessor.getClassID(id, GDEF.markAttachClassDef)
          : 0;
    } else {
      this.isMark =
          this.codePoints.length > 0 && this.codePoints.every(checkMark);
      this.isBase = !this.isMark;
      this.isLigature = this.codePoints.length > 1;
      this.markAttachmentType = 0;
    }
  }

  copy() {
    return GlyphInfo(this.font, this.id, this.codePoints, this.features);
  }
}
