import 'dart:typed_data';

import 'gsub_parser.dart';

class GDEFParser {
  GDEFParser({required this.data, this.startPosition = 0}) {
    var base = this.startPosition;
    var majorVersion = data.getUint16(base + 0);
    var minorVersion = data.getUint16(base + 2);
    var glyphClassDefOffset = base + data.getUint16(base + 4);
    var attachListOffset = base + data.getUint16(base + 6);
    var ligCaretListOffset = base + data.getUint16(base + 8);
    var markAttachClassDefOffset = base + data.getUint16(base + 10);
    glyphClassDef = ClassDef.parse(data, glyphClassDefOffset);
    attachList = null;
    ligCaretList = null;
    markAttachClassDef = ClassDef.parse(data, markAttachClassDefOffset);
  }
  final ByteData data;
  final int startPosition;
  late ClassDef? glyphClassDef;
  late ClassDef? markAttachClassDef;
  dynamic attachList;
  dynamic ligCaretList;
}
