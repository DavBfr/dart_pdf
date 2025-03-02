import 'dart:typed_data';

// Header
class GsubHeader {
  GsubHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.scriptListOffset,
    required this.featureListOffset,
    required this.lookupListOffset,
  });
  final int majorVersion;
  final int minorVersion;
  final int scriptListOffset;
  final int featureListOffset;
  final int lookupListOffset;

  static GsubHeader parse(ByteData data, int base) {
    return GsubHeader(
      majorVersion: data.getUint16(base + 0),
      minorVersion: data.getUint16(base + 2),
      scriptListOffset: base + data.getUint16(base + 4),
      featureListOffset: base + data.getUint16(base + 6),
      lookupListOffset: base + data.getUint16(base + 8),
    );
  }
}

// Scripts
class ScriptRecord {
  ScriptRecord(this.tag, this.offset, this.scriptTable);
  final String tag;
  final int offset;
  ScriptTable scriptTable;

  static ScriptRecord parse(ByteData data, int recordOffset, int baseOffset) {
    final tag = String.fromCharCodes([
      data.getUint8(recordOffset),
      data.getUint8(recordOffset + 1),
      data.getUint8(recordOffset + 2),
      data.getUint8(recordOffset + 3),
    ]);
    final scriptOffset = data.getUint16(recordOffset + 4);

    final tableOffset = baseOffset + scriptOffset;
    final defaultLangSysOffset = data.getUint16(tableOffset);
    final langSysCount = data.getUint16(tableOffset + 2);

    final defaultLangSys = defaultLangSysOffset != 0
        ? LangSysTable.parse(data, tableOffset + defaultLangSysOffset)
        : null;

    int langSysRecordOffset = tableOffset + 4;
    List<LangSysRecord> langSysRecords = [];
    for (int i = 0; i < langSysCount; i++) {
      langSysRecords.add(
        LangSysRecord.parse(data, langSysRecordOffset, tableOffset),
      );
      langSysRecordOffset += 6;
    }

    final scriptTable = ScriptTable(
      defaultLangSysOffset,
      langSysRecords,
      defaultLangSys,
    );

    return ScriptRecord(tag, scriptOffset, scriptTable);
  }
}

class ScriptTable {
  ScriptTable(
      this.defaultLangSysOffset,
      this.langSysRecords,
      this.defaultLangSys,
      );
  final int defaultLangSysOffset;
  final List<LangSysRecord> langSysRecords;
  final LangSysTable? defaultLangSys;
}

class LangSysRecord {
  LangSysRecord({
    required this.langSysTag,
    required this.langSysOffset,
    this.langSys,
  });
  final String langSysTag;
  final int langSysOffset;
  final LangSysTable? langSys;

  static LangSysRecord parse(ByteData data, int recordOffset, int tableOffset) {
    final langSysTag = String.fromCharCodes([
      data.getUint8(recordOffset),
      data.getUint8(recordOffset + 1),
      data.getUint8(recordOffset + 2),
      data.getUint8(recordOffset + 3),
    ]);
    final langSysOffset = data.getUint16(recordOffset + 4);

    final langSys = LangSysTable.parse(data, tableOffset + langSysOffset);

    return LangSysRecord(
      langSysTag: langSysTag,
      langSysOffset: langSysOffset,
      langSys: langSys,
    );
  }
}

class LangSysTable {
  LangSysTable(this.featureCount, this.reqFeatureIndex, this.featureIndexes);
  final int featureCount;
  final int reqFeatureIndex;
  final List<int> featureIndexes;

  static LangSysTable parse(ByteData data, int offset) {
    final featureCount = data.getUint16(offset);
    final reqFeatureIndex = data.getUint16(offset + 2);
    final featureIndexCount = data.getUint16(offset + 4);

    List<int> featureIndexes = [];
    int featureIndexOffset = offset + 6;

    for (int i = 0; i < featureIndexCount; i++) {
      featureIndexes.add(data.getUint16(featureIndexOffset));
      featureIndexOffset += 2;
    }

    return LangSysTable(featureCount, reqFeatureIndex, featureIndexes);
  }
}

class ScriptList {
  ScriptList(this.count, this.scriptRecords);
  final int count;
  final List<ScriptRecord> scriptRecords;

  static ScriptList parse(ByteData data, GsubHeader header) {
    final count = data.getUint16(header.scriptListOffset);
    int scriptRecordOffset = header.scriptListOffset + 2;
    List<ScriptRecord> scriptRecords = [];
    for (int i = 0; i < count; i++) {
      scriptRecords.add(
        ScriptRecord.parse(data, scriptRecordOffset, header.scriptListOffset),
      );
      scriptRecordOffset += 6;
    }
    return ScriptList(count, scriptRecords);
  }
}

// Features
class FeatureRecord {
  FeatureRecord(this.featureTag, this.featureOffset, this.feature);
  final String featureTag;
  final int featureOffset;
  final FeatureTable feature;

  static FeatureRecord parse(ByteData data, int recordOffset, int baseOffset) {
    final featureTag = String.fromCharCodes([
      data.getUint8(recordOffset),
      data.getUint8(recordOffset + 1),
      data.getUint8(recordOffset + 2),
      data.getUint8(recordOffset + 3),
    ]);
    final featureOffset = data.getUint16(recordOffset + 4);
    final feature = FeatureTable.parse(data, baseOffset + featureOffset);
    return FeatureRecord(featureTag, featureOffset, feature);
  }
}

class FeatureTable {
  FeatureTable(this.featureParams, this.lookupListIndexes, this.lookupCount);
  final int featureParams;
  final List<int> lookupListIndexes;
  final int lookupCount;

  static FeatureTable parse(ByteData data, int offset) {
    final featureParamsOffset = data.getUint16(offset);
    final lookupIndexCount = data.getUint16(offset + 2);
    List<int> lookupListIndexes = [];
    for (int i = 0; i < lookupIndexCount; i++) {
      lookupListIndexes.add(data.getUint16(offset + 4 + (i * 2)));
    }
    return FeatureTable(
        featureParamsOffset, lookupListIndexes, lookupIndexCount);
  }
}

class FeatureList {
  FeatureList(this.featureCount, this.featureRecords);
  final int featureCount;
  final List<FeatureRecord> featureRecords;

  static FeatureList parse(ByteData data, GsubHeader header) {
    final featureCount = data.getUint16(header.featureListOffset);
    int featureRecordOffset = header.featureListOffset + 2;
    List<FeatureRecord> featureRecords = [];

    for (int i = 0; i < featureCount; i++) {
      featureRecords.add(FeatureRecord.parse(
        data,
        featureRecordOffset,
        header.featureListOffset,
      ));
      featureRecordOffset += 6;
    }

    return FeatureList(featureCount, featureRecords);
  }
}

// Lookups
class Lookup {
  Lookup(
      this.lookupType,
      this.flags,
      this.subTableCount,
      this.subTables,
      this.markFilteringSet,
      this.pointer,
      );
  final int lookupType;
  final LookupFlag flags;
  final int subTableCount;
  final List<dynamic> subTables;
  final int? markFilteringSet;
  final int pointer;

  static Lookup parse(ByteData data, int offset) {
    int pointer = 0;
    final lookupType = data.getUint16(offset);
    pointer += 2;
    final lookupFlag = LookupFlag.parse(data, offset + 1);
    pointer += 2;

    final subTableCount = data.getUint16(offset + pointer);
    pointer += 2;
    List<dynamic> subTables = [];
    if (subTableCount > 0) {
      int subTableBase = offset + pointer;
      pointer += 2;
      for (int i = 0; i < subTableCount; i++) {
        var subTableOffsets = offset + data.getUint16(subTableBase + 2 * i);
        SubTable table = SubTable.parse(data, subTableOffsets, lookupType);
        subTables.add(table.substituteTable);
      }
    }

    int? markFilteringSet;
    if (lookupFlag.flags['useMarkFilteringSet'] == true) {
      markFilteringSet = data.getUint16(offset + pointer);
      pointer += 2;
    }

    return Lookup(
      lookupType,
      lookupFlag,
      subTableCount,
      subTables,
      markFilteringSet,
      pointer,
    );
  }
}

class LookupFlag {
  LookupFlag(this.markAttachmentType, this.bitFlag, this.flags);
  final int markAttachmentType;
  final int bitFlag;
  final Map<String, bool> flags;

  static LookupFlag parse(ByteData data, int offset) {
    int markAttachmentType = data.getUint8(offset);
    int bitFlag = data.getUint8(offset + 1);
    String bitString = bitFlag.toRadixString(2).padLeft(8, '0');
    Map<String, bool> flags = {
      'rightToLeft': bitString[0] == '1',
      'ignoreBaseGlyphs': bitString[1] == '1',
      'ignoreLigatures': bitString[2] == '1',
      'ignoreMarks': bitString[3] == '1',
      'useMarkFilteringSet': bitString[4] == '1',
    };
    return LookupFlag(markAttachmentType, bitFlag, flags);
  }
}

class SingleSubstitution {
  SingleSubstitution(
      this.substFormat,
      this.coverageOffset,
      this.coverage,
      this.deltaGlyphID,
      this.glyphCount,
      this.substitute,
      this.pointer,
      );
  final int substFormat;
  final int coverageOffset;
  final Coverage coverage;
  final int? deltaGlyphID;
  final int? glyphCount;
  final List<int>? substitute;
  final int pointer;

  static SingleSubstitution parse(ByteData data, int offset) {
    int pointer = 0;
    final substFormat = data.getUint16(offset);
    pointer += 2;
    final coverageOffset = offset + data.getUint16(offset + pointer);
    pointer += 2;
    final coverage = Coverage.parse(data, coverageOffset);

    int? deltaGlyphID;
    int? glyphCount;
    List<int>? substitute;
    if (substFormat == 1) {
      deltaGlyphID = data.getInt16(offset + pointer);
      pointer += 2;
    } else if (substFormat == 2) {
      glyphCount = data.getUint16(offset + pointer);
      pointer += 2;

      if (glyphCount > 0) {
        List<int> substitute = [];
        int substituteOffset = offset + pointer;
        for (int i = 0; i < glyphCount; i++) {
          substitute.add(data.getUint16(substituteOffset));
          substituteOffset += 2;
          pointer += 2;
        }
      }
    } else {
      throw UnsupportedError(
          "Unsupported SingleSubstitution format: $substFormat");
    }

    return SingleSubstitution(
      substFormat,
      coverageOffset,
      coverage,
      deltaGlyphID,
      glyphCount,
      substitute,
      pointer,
    );
  }
}

class MultipleSubstitutionSubTable {
  MultipleSubstitutionSubTable(this.substFormat, this.coverageOffset,
      this.sequenceCount, this.sequenceOffsets);
  final int substFormat;
  final int coverageOffset;
  final int sequenceCount;
  final List<int> sequenceOffsets;

  static MultipleSubstitutionSubTable parse(ByteData data, int offset) {
    final substFormat = data.getUint16(offset);
    final coverageOffset = data.getUint16(offset + 2);
    final sequenceCount = data.getUint16(offset + 4);
    List<int> sequenceOffsets = [];
    for (int i = 0; i < sequenceCount; i++) {
      sequenceOffsets.add(data.getUint16(offset + 6 + (i * 2)));
    }
    return MultipleSubstitutionSubTable(
        substFormat, coverageOffset, sequenceCount, sequenceOffsets);
  }
}

class AlternateSubstitutionSubTable {
  AlternateSubstitutionSubTable(this.substFormat, this.coverageOffset,
      this.alternateSetCount, this.alternateSetOffsets);
  final int substFormat;
  final int coverageOffset;
  final int alternateSetCount;
  final List<int> alternateSetOffsets;

  static AlternateSubstitutionSubTable parse(ByteData data, int offset) {
    final substFormat = data.getUint16(offset);
    final coverageOffset = data.getUint16(offset + 2);
    final alternateSetCount = data.getUint16(offset + 4);
    List<int> alternateSetOffsets = [];
    for (int i = 0; i < alternateSetCount; i++) {
      alternateSetOffsets.add(data.getUint16(offset + 6 + (i * 2)));
    }
    return AlternateSubstitutionSubTable(
        substFormat, coverageOffset, alternateSetCount, alternateSetOffsets);
  }
}

class LigatureSubstitution {
  LigatureSubstitution(
      this.substFormat,
      this.coverageOffset,
      this.coverage,
      this.ligatureSetCount,
      this.ligatureSet,
      this.pointer,
      );
  final int substFormat;
  final int coverageOffset;
  final Coverage coverage;
  final int ligatureSetCount;
  final List<LigatureSet> ligatureSet;
  final int pointer;

  static LigatureSubstitution parse(ByteData data, int offset) {
    int pointer = 0;
    final substFormat = data.getUint16(offset);
    pointer += 2;
    final coverageOffset = offset + data.getUint16(offset + pointer);
    pointer += 2;
    final coverage = Coverage.parse(data, coverageOffset);

    final ligatureSetCount = data.getUint16(offset + pointer);
    List<LigatureSet> ligatureSet = [];
    pointer += 2;
    if (ligatureSetCount > 0) {
      int ligatureSetBase = offset + pointer;
      pointer += 2;
      for (int i = 0; i < ligatureSetCount; i++) {
        var ligatureSetOffset =
            offset + data.getUint16(ligatureSetBase + 2 * i);
        var ligSet = LigatureSet.parse(data, ligatureSetOffset);
        ligatureSet.add(ligSet);
      }
    }

    return LigatureSubstitution(
      substFormat,
      coverageOffset,
      coverage,
      ligatureSetCount,
      ligatureSet,
      pointer,
    );
  }
}

class LigatureSet {
  LigatureSet(this.ligatureCount, this.ligatures, this.pointer);
  final int ligatureCount;
  final List<Ligature> ligatures;
  final int pointer;

  static LigatureSet parse(ByteData data, int offset) {
    int pointer = 0;
    final ligatureCount = data.getUint16(offset);
    pointer += 2;
    List<Ligature> ligatures = [];
    if (ligatureCount > 0) {
      int ligatureBase = offset + pointer;
      pointer += 2;
      for (int i = 0; i < ligatureCount; i++) {
        var ligatureOffset = offset + data.getUint16(ligatureBase + 2 * i);
        Ligature ligature = Ligature.parse(data, ligatureOffset);
        ligatures.add(ligature);
      }
    }

    return LigatureSet(ligatureCount, ligatures, pointer);
  }
}

class Ligature {
  Ligature(this.glyph, this.compCount, this.components, this.pointer);
  final int glyph;
  final int compCount;
  final List<int> components;
  final int pointer;

  static Ligature parse(ByteData data, int offset) {
    int pointer = 0;
    final glyph = data.getUint16(offset);
    pointer += 2;

    final compCount = data.getUint16(offset + pointer);
    pointer += 2;
    List<int> components = [];
    if (compCount - 1 > 0) {
      int compOffset = offset + pointer;
      for (int i = 0; i < compCount - 1; i++) {
        components.add(data.getUint16(compOffset));
        compOffset += 2;
        pointer += 2;
      }
    }

    return Ligature(glyph, compCount, components, pointer);
  }
}

class Coverage {
  Coverage(
      this.format,
      this.glyphCount,
      this.glyphs,
      this.rangeCount,
      this.rangeRecords,
      this.pointer,
      );
  final int format;
  final int? glyphCount;
  final List<int>? glyphs;
  final int? rangeCount;
  final List<RangeRecord>? rangeRecords;
  final int pointer;

  static Coverage parse(ByteData data, int offset) {
    int pointer = 0;
    final format = data.getUint16(offset);
    pointer += 2;

    int? glyphCount;
    List<int>? glyphs;
    int? rangeCount;
    List<RangeRecord>? rangeRecords;

    if (format == 1) {
      glyphs = [];
      glyphCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (glyphCount > 0) {
        int glyphsOffset = offset + pointer;
        for (int i = 0; i < glyphCount; i++) {
          glyphs.add(data.getUint16(glyphsOffset));
          glyphsOffset += 2;
          pointer += 2;
        }
      }
    } else if (format == 2) {
      rangeRecords = [];
      rangeCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (rangeCount > 0) {
        int rangeRecordOffset = offset + pointer;
        for (int i = 0; i < rangeCount; i++) {
          var record = RangeRecord.parse(data, rangeRecordOffset);
          rangeRecords.add(record);
          rangeRecordOffset += record.pointer;
          pointer += record.pointer;
        }
      }
    }

    return Coverage(
      format,
      glyphCount,
      glyphs,
      rangeCount,
      rangeRecords,
      pointer,
    );
  }
}

class RangeRecord {
  RangeRecord(this.start, this.end, this.startCoverageIndex, this.pointer);
  final int start;
  final int end;
  final int startCoverageIndex;
  final int pointer;

  static RangeRecord parse(ByteData data, int offset) {
    int pointer = 0;
    final start = data.getUint16(offset);
    pointer += 2;
    final end = data.getUint16(offset + pointer);
    pointer += 2;
    final startCoverageIndex = data.getUint16(offset + pointer);
    pointer += 2;
    return RangeRecord(start, end, startCoverageIndex, pointer);
  }
}

class ContextualSubstitutionSubTable {
  ContextualSubstitutionSubTable(this.substFormat, this.coverageOffset,
      [this.subRuleSetOffsets, this.subClassSetCount, this.subClassSetOffsets]);
  final int substFormat;
  final int coverageOffset;
  final List<int>? subRuleSetOffsets;
  final int? subClassSetCount;
  final List<int>? subClassSetOffsets;

  static ContextualSubstitutionSubTable parse(ByteData data, int offset) {
    final substFormat = data.getUint16(offset);
    final coverageOffset = data.getUint16(offset + 2);

    if (substFormat == 1) {
      final subRuleSetCount = data.getUint16(offset + 4);
      List<int> subRuleSetOffsets = [];
      for (int i = 0; i < subRuleSetCount; i++) {
        subRuleSetOffsets.add(data.getUint16(offset + 6 + (i * 2)));
      }
      return ContextualSubstitutionSubTable(
          substFormat, coverageOffset, subRuleSetOffsets);
    } else if (substFormat == 2) {
      final subClassSetCount = data.getUint16(offset + 4);
      List<int> subClassSetOffsets = [];
      for (int i = 0; i < subClassSetCount; i++) {
        subClassSetOffsets.add(data.getUint16(offset + 6 + (i * 2)));
      }
      return ContextualSubstitutionSubTable(substFormat, coverageOffset, null,
          subClassSetCount, subClassSetOffsets);
    } else {
      throw UnsupportedError(
          "Unsupported ContextualSubstitutionSubTable format: $substFormat");
    }
  }
}

class ChainingContext {
  ChainingContext(
      this.substFormat,
      this.coverageOffset,
      this.coverage,
      this.chainCount,
      this.chainRuleSets,
      this.backtrackClassDef,
      this.inputClassDef,
      this.lookaheadClassDef,
      this.chainClassSet,
      this.backtrackGlyphCount,
      this.backtrackCoverage,
      this.inputGlyphCount,
      this.inputCoverage,
      this.lookaheadGlyphCount,
      this.lookaheadCoverage,
      this.lookupCount,
      this.lookupRecords,
      this.pointer,
      );
  final int substFormat;
  final int? coverageOffset;
  final Coverage? coverage;
  final int? chainCount;
  final List<ChainRuleSets>? chainRuleSets;
  final ClassDef? backtrackClassDef;
  final ClassDef? inputClassDef;
  final ClassDef? lookaheadClassDef;
  final List<ChainRuleSets>? chainClassSet;
  final int? backtrackGlyphCount;
  final List<Coverage>? backtrackCoverage;
  final int? inputGlyphCount;
  final List<Coverage>? inputCoverage;
  final int? lookaheadGlyphCount;
  final List<Coverage>? lookaheadCoverage;
  final int? lookupCount;
  final List<LookupRecord>? lookupRecords;
  final int pointer;

  static ChainingContext parse(ByteData data, int offset) {
    int pointer = 0;
    final substFormat = data.getUint16(offset);
    pointer += 2;

    int? coverageOffset;
    Coverage? coverage;
    int? chainCount;
    List<ChainRuleSets>? chainRuleSets;
    ClassDef? backtrackClassDef;
    ClassDef? inputClassDef;
    ClassDef? lookaheadClassDef;
    List<ChainRuleSets>? chainClassSet;
    int? backtrackGlyphCount;
    List<Coverage>? backtrackCoverage;
    int? inputGlyphCount;
    List<Coverage>? inputCoverage;
    int? lookaheadGlyphCount;
    List<Coverage>? lookaheadCoverage;
    int? lookupCount;
    List<LookupRecord>? lookupRecords;

    if (substFormat == 1) {
      // Simple context glyph substitution
      coverageOffset = offset + data.getUint16(offset + pointer);
      pointer += 2;
      coverage = Coverage.parse(data, coverageOffset);
      chainCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (chainCount > 0) {
        int chainRuleBase = offset + pointer;
        chainRuleSets = [];
        for (int i = 0; i < chainCount; i++) {
          var chainRuleOffset = offset + data.getUint16(chainRuleBase + 2 * i);
          ChainRuleSets chainRule = ChainRuleSets.parse(data, chainRuleOffset);
          chainRuleSets.add(chainRule);
        }
      }
    } else if (substFormat == 2) {
      // Class-based chaining context
      coverageOffset = offset + data.getUint16(offset + pointer);
      pointer += 2;
      coverage = Coverage.parse(data, coverageOffset);

      int backtrackClassDefOffset = offset + data.getUint16(offset + pointer);
      pointer += 2;
      backtrackClassDef = ClassDef.parse(data, backtrackClassDefOffset);

      int inputClassDefOffset = offset + data.getUint16(offset + pointer);
      pointer += 2;
      inputClassDef = ClassDef.parse(data, inputClassDefOffset);

      int lookaheadClassDefOffset = offset + data.getUint16(offset + pointer);
      pointer += 2;
      lookaheadClassDef = ClassDef.parse(data, lookaheadClassDefOffset);

      chainCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (chainCount > 0) {
        int chainClassBase = offset + pointer;
        chainClassSet = [];
        for (int i = 0; i < chainCount; i++) {
          var chainClassOffset =
              offset + data.getUint16(chainClassBase + 2 * i);
          chainClassSet.add(ChainRuleSets.parse(data, chainClassOffset));
        }
      }
    } else if (substFormat == 3) {
      // Coverage-based chaining context
      backtrackGlyphCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (backtrackGlyphCount > 0) {
        int backtrackBase = offset + pointer;
        pointer += backtrackGlyphCount * 2;
        backtrackCoverage = [];
        for (int i = 0; i < backtrackGlyphCount; i++) {
          var backtrackOffset = offset + data.getUint16(backtrackBase + 2 * i);
          var coverage = Coverage.parse(data, backtrackOffset);
          backtrackCoverage.add(coverage);
        }
      }

      inputGlyphCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (inputGlyphCount > 0) {
        int inputBase = offset + pointer;
        pointer += inputGlyphCount * 2;
        inputCoverage = [];
        for (int i = 0; i < inputGlyphCount; i++) {
          var inputOffset = offset + data.getUint16(inputBase + 2 * i);
          var coverage = Coverage.parse(data, inputOffset);
          inputCoverage.add(coverage);
        }
      }

      lookaheadGlyphCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (lookaheadGlyphCount > 0) {
        int lookaheadBase = offset + pointer;
        pointer += lookaheadGlyphCount * 2;
        lookaheadCoverage = [];
        for (int i = 0; i < lookaheadGlyphCount; i++) {
          var lookaheadOffset = offset + data.getUint16(lookaheadBase + 2 * i);
          var coverage = Coverage.parse(data, lookaheadOffset);
          lookaheadCoverage.add(coverage);
        }
      }

      lookupCount = data.getUint16(offset + pointer);
      pointer += 2;
      int lookupOffset = offset + pointer;
      lookupRecords = [];
      for (int i = 0; i < lookupCount; i++) {
        lookupRecords.add(LookupRecord.parse(data, lookupOffset));
        lookupOffset += 4;
        pointer += 4;
      }
    } else {
      throw UnsupportedError(
          "Unsupported ChainedContextualSubstitutionSubTable format: $substFormat");
    }
    return ChainingContext(
      substFormat,
      coverageOffset,
      coverage,
      chainCount,
      chainRuleSets,
      backtrackClassDef,
      inputClassDef,
      lookaheadClassDef,
      chainClassSet,
      backtrackGlyphCount,
      backtrackCoverage,
      inputGlyphCount,
      inputCoverage,
      lookaheadGlyphCount,
      lookaheadCoverage,
      lookupCount,
      lookupRecords,
      pointer,
    );
  }
}

class ChainRuleSets {
  ChainRuleSets(this.chainRuleCount, this.chainRules, this.pointer);
  final int chainRuleCount;
  final List<ChainRule> chainRules;
  final int pointer;

  static ChainRuleSets parse(ByteData data, int offset) {
    int pointer = 0;
    int chainRuleCount = data.getUint16(offset);
    pointer += 2;
    List<ChainRule> chainRules = [];
    if (chainRuleCount > 0) {
      int chainRuleBase = offset + pointer;
      var chainRuleOffset = offset + data.getUint16(chainRuleBase);
      for (int i = 0; i < chainRuleCount; i++) {
        var rule = ChainRule.parse(data, chainRuleOffset);
        chainRules.add(rule);
        chainRuleOffset += rule.pointer;
        pointer += rule.pointer;
      }
    }

    return ChainRuleSets(chainRuleCount, chainRules, pointer);
  }
}

class ChainRule {
  ChainRule(
      this.backtrackGlyphCount,
      this.backtrack,
      this.inputGlyphCount,
      this.input,
      this.lookaheadGlyphCount,
      this.lookahead,
      this.lookupCount,
      this.lookupRecords,
      this.pointer,
      );
  final int backtrackGlyphCount;
  final List<int> backtrack;
  final int inputGlyphCount;
  final List<int> input;
  final int lookaheadGlyphCount;
  final List<int> lookahead;
  final int lookupCount;
  final List<LookupRecord> lookupRecords;
  final int pointer;

  static ChainRule parse(ByteData data, int offset) {
    int pointer = 0;
    int backtrackGlyphCount = data.getUint16(offset);
    pointer += 2;
    List<int> backtrack = [];
    if (backtrackGlyphCount > 0) {
      int backtrackOffset = offset + pointer;
      for (int i = 0; i < backtrackGlyphCount; i++) {
        backtrack.add(data.getUint16(backtrackOffset));
        backtrackOffset += 2;
        pointer += 2;
      }
    }

    int inputGlyphCount = data.getUint16(offset + pointer) - 1;
    pointer += 2;
    List<int> input = [];
    if (inputGlyphCount > 0) {
      int inputOffset = offset + pointer;
      for (int i = 0; i < inputGlyphCount; i++) {
        input.add(data.getUint16(inputOffset));
        inputOffset += 2;
        pointer += 2;
      }
    }

    int lookaheadGlyphCount = data.getUint16(offset + pointer);
    pointer += 2;
    List<int> lookahead = [];
    if (lookaheadGlyphCount > 0) {
      int lookaheadOffset = offset + pointer;
      for (int i = 0; i < lookaheadGlyphCount; i++) {
        lookahead.add(data.getUint16(lookaheadOffset));
        lookaheadOffset += 2;
        pointer += 2;
      }
    }

    int lookupCount = data.getUint16(offset + pointer);
    pointer += 2;
    List<LookupRecord> lookupRecords = [];
    if (lookupCount > 0) {
      int lookupOffset = offset + pointer;
      for (int i = 0; i < lookupCount; i++) {
        var record = LookupRecord.parse(data, lookupOffset);
        lookupRecords.add(record);
        lookupOffset += record.pointer;
        pointer += record.pointer;
      }
    }

    return ChainRule(
      backtrackGlyphCount,
      backtrack,
      inputGlyphCount,
      input,
      lookaheadGlyphCount,
      lookahead,
      lookupCount,
      lookupRecords,
      pointer,
    );
  }
}

class LookupRecord {
  LookupRecord(this.sequenceIndex, this.lookupListIndex, this.pointer);
  final int sequenceIndex;
  final int lookupListIndex;
  final int pointer;

  static LookupRecord parse(ByteData data, int offset) {
    int pointer = 0;
    int sequenceIndex = data.getUint16(offset);
    pointer += 2;
    int lookupListIndex = data.getUint16(offset + pointer);
    pointer += 2;
    return LookupRecord(sequenceIndex, lookupListIndex, pointer);
  }
}

class ClassDef {
  ClassDef(
      this.classDefFormat,
      this.startGlyph,
      this.glyphCount,
      this.classValueArray,
      this.classRangeCount,
      this.classRangeRecord,
      this.pointer,
      );
  final int classDefFormat;
  final int? startGlyph;
  final int? glyphCount;
  final List<int>? classValueArray;
  final int? classRangeCount;
  final List<ClassRangeRecord>? classRangeRecord;
  final int pointer;

  static ClassDef parse(ByteData data, int offset) {
    int pointer = 0;
    int classDefFormat = data.getUint16(offset);
    pointer += 2;

    int? startGlyph;
    int? glyphCount;
    List<int>? classValueArray;
    int? classRangeCount;
    List<ClassRangeRecord>? classRangeRecords;
    if (classDefFormat == 1) {
      startGlyph = data.getUint16(offset + pointer);
      pointer += 2;

      glyphCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (glyphCount > 0) {
        classValueArray = [];
        int classValueOffset = offset + pointer;
        for (int i = 0; i < glyphCount; i++) {
          classValueArray.add(data.getUint16(classValueOffset));
          classValueOffset += 2;
          pointer += 2;
        }
      }
    } else if (classDefFormat == 2) {
      classRangeCount = data.getUint16(offset + pointer);
      pointer += 2;
      if (classRangeCount > 0) {
        int classRecordOffset = offset + pointer;
        classRangeRecords = [];
        for (int i = 0; i < classRangeCount; i++) {
          var record = ClassRangeRecord.parse(data, classRecordOffset);
          classRangeRecords.add(record);
          classRecordOffset += record.pointer;
          pointer += record.pointer;
        }
      }
    }

    return ClassDef(
      classDefFormat,
      startGlyph,
      glyphCount,
      classValueArray,
      classRangeCount,
      classRangeRecords,
      pointer,
    );
  }
}

class ClassRangeRecord {
  ClassRangeRecord(this.start, this.end, this.classValue, this.pointer);
  final int start;
  final int end;
  final int classValue;
  final int pointer;

  static ClassRangeRecord parse(ByteData data, int offset) {
    int pointer = 0;
    int start = data.getUint16(offset);
    pointer += 2;
    int end = data.getUint16(offset + pointer);
    pointer += 2;
    int classValue = data.getUint16(offset + pointer);
    pointer += 2;
    return ClassRangeRecord(start, end, classValue, pointer);
  }
}

class ExtensionSubstitutionSubTable {
  ExtensionSubstitutionSubTable(
      this.substFormat, this.extensionLookupType, this.extensionOffset);
  final int substFormat;
  final int extensionLookupType;
  final int extensionOffset;

  static ExtensionSubstitutionSubTable parse(ByteData data, int offset) {
    final substFormat = data.getUint16(offset);
    final extensionLookupType = data.getUint16(offset + 2);
    final extensionOffset = data.getUint32(offset + 4);
    return ExtensionSubstitutionSubTable(
        substFormat, extensionLookupType, extensionOffset);
  }
}

class ReverseChainedContextualSingleSubstitutionSubTable {
  ReverseChainedContextualSingleSubstitutionSubTable(
      this.substFormat,
      this.coverageOffset,
      this.backtrackGlyphCount,
      this.backtrackCoverageOffsets,
      this.lookaheadGlyphCount,
      this.lookaheadCoverageOffsets,
      this.substituteGlyphCount,
      this.substituteGlyphIDs);
  final int substFormat;
  final int coverageOffset;
  final int backtrackGlyphCount;
  final List<int> backtrackCoverageOffsets;
  final int lookaheadGlyphCount;
  final List<int> lookaheadCoverageOffsets;
  final int substituteGlyphCount;
  final List<int> substituteGlyphIDs;

  static ReverseChainedContextualSingleSubstitutionSubTable parse(
      ByteData data, int offset) {
    final substFormat = data.getUint16(offset);
    final coverageOffset = data.getUint16(offset + 2);
    final backtrackGlyphCount = data.getUint16(offset + 4);
    List<int> backtrackCoverageOffsets = [];
    for (int i = 0; i < backtrackGlyphCount; i++) {
      backtrackCoverageOffsets.add(data.getUint16(offset + 6 + (i * 2)));
    }

    final lookaheadGlyphCount =
    data.getUint16(offset + 6 + (backtrackGlyphCount * 2));
    List<int> lookaheadCoverageOffsets = [];
    for (int i = 0; i < lookaheadGlyphCount; i++) {
      lookaheadCoverageOffsets.add(
          data.getUint16(offset + 8 + (backtrackGlyphCount * 2) + (i * 2)));
    }

    final substituteGlyphCount = data.getUint16(
        offset + 8 + (backtrackGlyphCount * 2) + (lookaheadGlyphCount * 2));
    List<int> substituteGlyphIDs = [];
    for (int i = 0; i < substituteGlyphCount; i++) {
      substituteGlyphIDs.add(data.getUint16(offset +
          10 +
          (backtrackGlyphCount * 2) +
          (lookaheadGlyphCount * 2) +
          (i * 2)));
    }

    return ReverseChainedContextualSingleSubstitutionSubTable(
        substFormat,
        coverageOffset,
        backtrackGlyphCount,
        backtrackCoverageOffsets,
        lookaheadGlyphCount,
        lookaheadCoverageOffsets,
        substituteGlyphCount,
        substituteGlyphIDs);
  }
}

class SubTable {
  SubTable(this.substituteTable, this.pointer);
  dynamic substituteTable;
  int pointer;

  static SubTable parse(ByteData data, int offset, int lookupType) {
    dynamic substituteTable;
    try {
      switch (lookupType) {
        case 1:
          substituteTable = SingleSubstitution.parse(data, offset);
          break;
      // case 2:
      //   substituteTable = MultipleSubstitutionSubTable.parse(data, offset);
      //   break;
      // case 3:
      //   substituteTable = AlternateSubstitutionSubTable.parse(data, offset);
      //   break;
        case 4:
          substituteTable = LigatureSubstitution.parse(data, offset);
          break;
      // case 5:
      //   substituteTable = ContextualSubstitutionSubTable.parse(data, offset);
      //   break;
        case 6:
          substituteTable = ChainingContext.parse(data, offset);
          break;
      // case 7:
      //   substituteTable = ExtensionSubstitutionSubTable.parse(data, offset);
      //   break;
      // case 8:
      //   substituteTable =
      //       ReverseChainedContextualSingleSubstitutionSubTable.parse(
      //           data, offset);
      //   break;
      // default:
      // throw UnsupportedError("Unsupported lookupType: $lookupType");
      }
    } catch (e) {
      print(e);
    }

    // Add parsing logic based on subTableFormat
    return SubTable(
      substituteTable,
      substituteTable?.pointer ?? 0,
    );
  }
}

class LookupList {
  LookupList(this.lookupCount, this.lookups);
  final int lookupCount;
  final List<Lookup> lookups;

  static LookupList parse(ByteData data, int offset) {
    final lookupCount = data.getUint16(offset);
    int lookupOffset = offset + 2;
    List<Lookup> lookups = [];

    for (int i = 0; i < lookupCount; i++) {
      int lookupOffsetOffset = data.getUint16(lookupOffset);
      lookups.add(Lookup.parse(data, offset + lookupOffsetOffset));
      lookupOffset += 2;
    }

    return LookupList(lookupCount, lookups);
  }
}

class GsubTableParser {
  // https://www.microsoft.com/typography/OTSPEC/gsub.htm
  GsubTableParser({required this.data, this.startPosition = 0}) {
    gsubHeader = GsubHeader.parse(data, startPosition);
    scriptList = ScriptList.parse(data, gsubHeader);
    featureList = FeatureList.parse(data, gsubHeader);
    lookupList = LookupList.parse(data, gsubHeader.lookupListOffset);
  }
  final ByteData data;
  final int startPosition;
  late GsubHeader gsubHeader;
  late ScriptList scriptList;
  late FeatureList featureList;
  late LookupList lookupList;
  dynamic featureVariations;
}