import 'gdef_parser.dart';
import 'ot_processor.dart';
import 'ttf_parser.dart';

class GlyphInfo {
  late TtfParser font;
  int _id = -1;
  bool isMultiplied = false;
  bool substituted = false;
  bool isLigated = false;
  bool isMark = false;
  bool isLigature = false;
  bool isBase = false;
  int markAttachmentType = 0;

  GlyphInfo(this.font, int glyphId) {
    id = glyphId;
  }

  int get id => _id;
  set id(int val) {
    _id = val;
    substituted = true;
    GDEFParser? GDEF = font.gdef;
    if (GDEF != null && GDEF.glyphClassDef != null) {
      var classID = OTProcessor.getClassID(id, GDEF.glyphClassDef!);
      isBase = classID == 1;
      isLigature = classID == 2;
      isMark = classID == 3;
      markAttachmentType = GDEF.markAttachClassDef != null
          ? OTProcessor.getClassID(id, GDEF.markAttachClassDef!)
          : 0;
    }
  }
}
