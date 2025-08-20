import 'package:meta/meta.dart';

enum HarfBuzzDirection {
  invalid(0),
  leftToRight(4),
  rightToLeft(5),
  topToBottom(6),
  bottomToTop(7);

  final int value;
  const HarfBuzzDirection(this.value);
}

enum HarfBuzzStyle {
  italic(0x6974616C),
  opticalSize(0x6F70737A),
  slantAngle(0x736C6E74),
  slantRatio(0x536C6E74),
  width(0x77647468),
  weight(0x77676874);

  final int value;
  const HarfBuzzStyle(this.value);
}

enum HarfBuzzName {
  fontFamily(1),
  fontSubFamily(2),
  uniqueId(3),
  fullName(4),
  postscriptName(6);

  final int value;
  const HarfBuzzName(this.value);
}

@immutable
class HarfbuzzFontExtents {
  final double ascender;
  final double descender;
  final double lineGap;
  HarfbuzzFontExtents(this.ascender, this.descender, this.lineGap);
}

@immutable
class HarfbuzzGlyphPosition {
  final double xAdvance;
  final double yAdvance;
  final double xOffset;
  final double yOffset;
  HarfbuzzGlyphPosition(this.xAdvance, this.yAdvance, this.xOffset, this.yOffset);

  @override
  String toString() => '(adv: ($xAdvance, $yAdvance), off: ($xOffset, $yOffset))';
}

@immutable
class HarfbuzzGlyphInfo {
  final int codepoint;
  final int cluster;
  HarfbuzzGlyphInfo(this.codepoint, this.cluster);

  @override
  String toString() => '(codepoint: $codepoint, cluster: $cluster)';
}
