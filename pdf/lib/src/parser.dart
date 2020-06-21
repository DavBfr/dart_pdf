// Parsing utility functions

import 'dart:typed_data';

// Retrieve an unsigned byte from the DataView.
int getByte(UnmodifiableByteDataView dataView, int offset) {
  return dataView.getUint8(offset);
}

// Retrieve an unsigned 16-bit short from the DataView.
// The value is stored in big endian.
int getUShort(UnmodifiableByteDataView dataView, int offset) {
  return dataView.getUint16(offset, Endian.big);
}

// Retrieve a signed 16-bit short from the DataView.
// The value is stored in big endian.
int getShort(UnmodifiableByteDataView dataView, int offset) {
  return dataView.getInt16(offset, Endian.big);
}

// Retrieve an unsigned 32-bit long from the DataView.
// The value is stored in big endian.
int getULong(UnmodifiableByteDataView dataView, int offset) {
  return dataView.getUint32(offset, Endian.big);
}

// Retrieve a 32-bit signed fixed-point number (16.16) from the DataView.
// The value is stored in big endian.
double getFixed(UnmodifiableByteDataView dataView, int offset) {
  int decimal = dataView.getInt16(offset, Endian.big);
  int fraction = dataView.getUint16(offset + 2, Endian.big);
  return decimal + fraction / 65535;
}

// Retrieve a 4-character tag from the DataView.
// Tags are used to identify tables.
String getTag(UnmodifiableByteDataView dataView, int offset) {
  String tag = '';
  for (int i = offset; i < offset + 4; i += 1) {
    tag += String.fromCharCode(dataView.getInt8(i));
  }

  return tag;
}

// Retrieve an offset from the DataView.
// Offsets are 1 to 4 bytes in length, depending on the offSize argument.
int getOffset(UnmodifiableByteDataView dataView, int offset, int offSize) {
  int v = 0;
  for (int i = 0; i < offSize; i += 1) {
    v <<= 8;
    v += dataView.getUint8(offset + i);
  }

  return v;
}

class Parser {
  final UnmodifiableByteDataView data;
  final int offset;
  int relativeOffset = 0;

  Map<String, int Function()> lookupRecordDesc;

  Map<String, Function> langSysTable;

  Parser(this.data, this.offset) {
    lookupRecordDesc = {
      "sequenceIndex": parseUShort,
      "lookupListIndex": parseUShort
    };

    langSysTable = {
      "reserved": parseUShort,
      "reqFeatureIndex": parseUShort,
      "featureIndexes": parseUShortList
    };
  }

  int parseOffset32() {
    return parseULong();
  }

  int parseULong() {
    int v = getULong(this.data, this.offset + this.relativeOffset);
    this.relativeOffset += 4;
    return v;
  }

  int parseShort() {
    int v = this.data.getInt16(this.offset + this.relativeOffset);
    this.relativeOffset += 2;
    return v;
  }

  int parseUShort() {
    int v = this.data.getUint16(this.offset + this.relativeOffset);
    this.relativeOffset += 2;
    return v;
  }

  int parseOffset16() {
    return parseUShort();
  }

  int offset16() {
    return parseOffset16();
  }

  parseVersion(int minorBase) {
    int major = getUShort(this.data, this.offset + this.relativeOffset);

    // How to interpret the minor version is very vague in the spec. 0x5000 is 5, 0x1000 is 1
    // Default returns the correct number if minor = 0xN000 where N is 0-9
    // Set minorBase to 1 for tables that use minor = N where N is 0-9
    int minor = getUShort(this.data, this.offset + this.relativeOffset + 2);
    this.relativeOffset += 4;
    if (minorBase == null) minorBase = 0x1000;
    return major + minor / minorBase / 10;
  }

  dynamic parseStruct(dynamic description) {
    if (description is Function) {
      return description.call(this);
    } else {
      var fields = (description as Map<String, dynamic>).keys.toList();
      var struct = <String, dynamic>{};
      for (int j = 0; j < fields.length; j++) {
        var fieldName = fields[j];
        dynamic fieldType = description[fieldName];
        struct[fieldName] = fieldType.call(this);
      }
      return struct;
    }
  }

  dynamic parsePointer(dynamic description) {
    int structOffset = this.parseOffset16();
    if (structOffset > 0) {
      // NULL offset => return undefined
      return Parser(this.data, this.offset + structOffset)
          .parseStruct(description);
    }
    return null;
  }

  List<int> parseUShortList(int count) {
    if (count == null) {
      count = this.parseUShort();
    }
    List<int> offsets = List<int>(count);
    var dataView = data;
    int offset = this.offset + this.relativeOffset;
    for (int i = 0; i < count; i++) {
      offsets[i] = dataView.getUint16(offset);
      offset += 2;
    }

    this.relativeOffset += count * 2;
    return offsets;
  }

  parseCoverage() {
    int startOffset = this.offset + this.relativeOffset;
    int format = this.parseUShort();
    int count = this.parseUShort();
    if (format == 1) {
      return {"format": 1, "glyphs": this.parseUShortList(count)};
    } else if (format == 2) {
      List<Map<String, int>> ranges = List<Map<String, int>>(count);
      for (int i = 0; i < count; i++) {
        ranges.add({
          "start": this.parseUShort(),
          "end": this.parseUShort(),
          "index": this.parseUShort()
        });
      }
      return {format: 2, ranges: ranges};
    }

    // throw new Error('0x' + startOffset.toString(16) + ': Coverage format must be 1 or 2.');
  }

  List<int> parseOffset16List(int count) {
    if (count == null) {
      count = this.parseUShort();
    }
    List<int> offsets = List<int>(count);
    var dataView = this.data;
    int offset = this.offset + this.relativeOffset;
    for (int i = 0; i < count; i++) {
      offsets[i] = dataView.getUint16(offset);
      offset += 2;
    }

    this.relativeOffset += count * 2;
    return offsets;
  }

  dynamic parseListOfLists(dynamic itemCallback) {
    List<int> offsets = this.parseOffset16List(null);
    int count = offsets.length;
    int relativeOffset = this.relativeOffset;
    List<dynamic> list = List(count);
    for (int i = 0; i < count; i++) {
      int start = offsets[i];
      if (start == 0) {
        // NULL offset
        // Add i as owned property to list. Convenient with assert.
        list[i] = null;
        continue;
      }
      this.relativeOffset = start;
      if (itemCallback) {
        var subOffsets = this.parseOffset16List(null);
        List<dynamic> subList = List(subOffsets.length);
        for (int j = 0; j < subOffsets.length; j++) {
          this.relativeOffset = start + subOffsets[j];
          subList[j] = itemCallback.call(this);
        }
        list[i] = subList;
      } else {
        list[i] = this.parseUShortList(null);
      }
    }
    this.relativeOffset = relativeOffset;
    return list;
  }

  dynamic parseRecordList(int count, dynamic recordDescription) {
    // If the count argument is absent, read it in the stream.
    if (count == null) {
      count = this.parseUShort();
    }
    List<dynamic> records = List(count);
    var fields = (recordDescription as Map<String, dynamic>).keys.toList();
    for (int i = 0; i < count; i++) {
      Map<String, dynamic> rec = {};
      for (int j = 0; j < fields.length; j++) {
        String fieldName = fields[j];
        dynamic fieldType = recordDescription[fieldName];
        rec[fieldName] = fieldType.call(this);
      }
      records[i] = rec;
    }
    return records;
  }

  // Parse a Class Definition Table in a GSUB, GPOS or GDEF table.
// https://www.microsoft.com/typography/OTSPEC/chapter2.htm
  Map<String, dynamic> parseClassDef() {
    int startOffset = this.offset + this.relativeOffset;
    int format = this.parseUShort();
    if (format == 1) {
      return {
        "format": 1,
        "startGlyph": this.parseUShort(),
        "classes": this.parseUShortList(null)
      };
    } else if (format == 2) {
      return {
        "format": 2,
        "ranges": this.parseRecordList(null, {
          "start:": parseUShort,
          "end:": parseUShort,
          "classId:": parseUShort
        }),
      };
    }
    //throw new Error('0x' + startOffset.toString(16) + ': ClassDef format must be 1 or 2.');
  }

  /**
   * Parse a list of items.
   * Record count is optional, if omitted it is read from the stream.
   * itemCallback is one of the Parser methods.
   */
  List<dynamic> parseList(int count, dynamic itemCallback) {
    if (count == null) {
      count = this.parseUShort();
    }
    List<dynamic> list = List(count);
    for (int i = 0; i < count; i++) {
      list[i] = itemCallback.call(this);
    }
    return list;
  }

  Map<String, dynamic> parseLookup1() {
    int start = this.offset + this.relativeOffset;
    int substFormat = this.parseUShort();
    if (substFormat == 1) {
      return {
        "substFormat": 1,
        "coverage": this.parsePointer(parseCoverage),
        "deltaGlyphId": this.parseUShort()
      };
    } else if (substFormat == 2) {
      return {
        "substFormat": 2,
        "coverage": this.parsePointer(parseCoverage),
        "substitute": this.parseOffset16List(null)
      };
    }

    return {};
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#MS
  Map<String, dynamic> parseLookup2() {
    int substFormat = this.parseUShort();
    //check.argument(substFormat == 1, 'GSUB Multiple Substitution Subtable identifier-format must be 1');
    return {
      "substFormat": substFormat,
      "coverage": this.parsePointer(parseCoverage),
      "sequences": this.parseListOfLists(null)
    };
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#AS
  Map<String, dynamic> parseLookup3() {
    int substFormat = this.parseUShort();
    //check.argument(substFormat == 1, 'GSUB Alternate Substitution Subtable identifier-format must be 1');
    return {
      "substFormat": substFormat,
      "coverage": this.parsePointer(parseCoverage),
      "alternateSets": this.parseListOfLists(null)
    };
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#LS
  Map<String, dynamic> parseLookup4() {
    int substFormat = this.parseUShort();
    //check.argument(substFormat == 1, 'GSUB ligature table identifier-format must be 1');
    return {
      "substFormat": substFormat,
      "coverage": this.parsePointer(parseCoverage),
      "ligatureSets": this.parseListOfLists(() {
        return {
          "ligGlyph": this.parseUShort(),
          "components": this.parseUShortList(this.parseUShort() - 1)
        };
      })
    };
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#CSF
  Map<String, dynamic> parseLookup5() {
    int start = this.offset + this.relativeOffset;
    int substFormat = this.parseUShort();

    if (substFormat == 1) {
      return {
        "substFormat": substFormat,
        "coverage": this.parsePointer(parseCoverage),
        "ruleSets": this.parseListOfLists(() {
          int glyphCount = this.parseUShort();
          int substCount = this.parseUShort();
          return {
            "input": this.parseUShortList(glyphCount - 1),
            "lookupRecords": this.parseRecordList(substCount, lookupRecordDesc)
          };
        })
      };
    } else if (substFormat == 2) {
      return {
        "substFormat": substFormat,
        "coverage": this.parsePointer(parseCoverage),
        "classDef": this.parsePointer(parseClassDef),
        "classSets": this.parseListOfLists(() {
          int glyphCount = this.parseUShort();
          int substCount = this.parseUShort();
          return {
            "classes": this.parseUShortList(glyphCount - 1),
            "lookupRecords": this.parseRecordList(substCount, lookupRecordDesc)
          };
        })
      };
    } else if (substFormat == 3) {
      int glyphCount = this.parseUShort();
      int substCount = this.parseUShort();
      return {
        "substFormat": substFormat,
        "coverages": this.parseList(glyphCount, parsePointer(parseCoverage)),
        "lookupRecords": this.parseRecordList(substCount, lookupRecordDesc)
      };
    }
    //check.assert(false, '0x' + start.toString(16) + ': lookup type 5 format must be 1, 2 or 3.');
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#CC
  Map<String, dynamic> parseLookup6() {
    int start = this.offset + this.relativeOffset;
    int substFormat = this.parseUShort();
    if (substFormat == 1) {
      return {
        "substFormat": 1,
        "coverage": this.parsePointer(parseCoverage),
        "chainRuleSets": this.parseListOfLists(() {
          return {
            "backtrack": this.parseUShortList(null),
            "input": this.parseUShortList(this.parseShort() - 1),
            "lookahead": this.parseUShortList(null),
            "lookupRecords": this.parseRecordList(null, lookupRecordDesc)
          };
        })
      };
    } else if (substFormat == 2) {
      return {
        "substFormat": 2,
        "coverage": this.parsePointer(parseCoverage),
        "backtrackClassDef": this.parsePointer(parseClassDef),
        "inputClassDef": this.parsePointer(parseClassDef),
        "lookaheadClassDef": this.parsePointer(parseClassDef),
        "chainClassSet": this.parseListOfLists(() {
          return {
            "backtrack": this.parseUShortList(null),
            "input": this.parseUShortList(this.parseShort() - 1),
            "lookahead": this.parseUShortList(null),
            "lookupRecords": this.parseRecordList(null, lookupRecordDesc)
          };
        })
      };
    } else if (substFormat == 3) {
      return {
        "substFormat": 3,
        "backtrackCoverage": this.parseList(null, parsePointer(parseCoverage)),
        "inputCoverage": this.parseList(null, parsePointer(parseCoverage)),
        "lookaheadCoverage": this.parseList(null, parsePointer(parseCoverage)),
        "lookupRecords": this.parseRecordList(null, lookupRecordDesc)
      };
    }
    //check.assert(false, '0x' + start.toString(16) + ': lookup type 6 format must be 1, 2 or 3.');
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#ES
  Map<String, dynamic> parseLookup7(List<dynamic> subtableParsers) {
    // Extension Substitution subtable
    int substFormat = this.parseUShort();
    //check.argument(substFormat == 1, 'GSUB Extension Substitution subtable identifier-format must be 1');
    int extensionLookupType = this.parseUShort();
    var extensionParser = Parser(this.data, this.offset + this.parseULong());
    return {
      "substFormat": 1,
      "lookupType": extensionLookupType,
      "extension": subtableParsers[extensionLookupType].call(extensionParser)
    };
  }

// https://www.microsoft.com/typography/OTSPEC/GSUB.htm#RCCS
  parseLookup8() {
    int substFormat = this.parseUShort();
    //check.argument(substFormat == 1, 'GSUB Reverse Chaining Contextual Single Substitution Subtable identifier-format must be 1');
    return {
      "substFormat": substFormat,
      "coverage": this.parsePointer(parseCoverage),
      "backtrackCoverage": this.parseList(null, parsePointer(parseCoverage)),
      "lookaheadCoverage": this.parseList(null, parsePointer(parseCoverage)),
      "substitutes": this.parseUShortList(null)
    };
  }

  dynamic recordList(int count, dynamic recordDescription) {
    return () {
      return this.parseRecordList(count, recordDescription);
    };
  }

  String parseTag() {
    return this.parseString(4);
  }

  String parseString(length) {
    var dataView = this.data;
    int offset = this.offset + this.relativeOffset;
    String string = '';
    this.relativeOffset += length;
    for (int i = 0; i < length; i++) {
      string += String.fromCharCode(dataView.getUint8(offset + i));
    }

    return string;
  }

  dynamic parseScriptList() {
    return this.parsePointer(recordList(null, {
          "tag": parseTag,
          "script": parsePointer({
            "defaultLangSys": parsePointer(langSysTable),
            "langSysRecords": recordList(
              null,
              {"tag": parseTag, "langSys": parsePointer(langSysTable)},
            )
          })
        })) ??
        [];
  }

  dynamic parseFeatureList() {
    return this.parsePointer(recordList(null, {
          "tag": parseTag,
          "feature": parsePointer(
              {"featureParams": offset16, "lookupListIndexes": parseUShortList})
        })) ??
        [];
  }

  dynamic list(int count, dynamic itemCallback) {
    return () {
      return this.parseList(count, itemCallback);
    };
  }

  parseLookupList(List<dynamic> lookupTableParsers) {
    return this.parsePointer(list(null, parsePointer(() {
          int lookupType = this.parseUShort();
          //check.argument(1 <= lookupType && lookupType <= 9, 'GPOS/GSUB lookup type ' + lookupType + ' unknown.');
          int lookupFlag = this.parseUShort();
          int useMarkFilteringSet = lookupFlag & 0x10;
          return {
            "lookupType": lookupType,
            "lookupFlag": lookupFlag,
            "subtables": this
                .parseList(null, parsePointer(lookupTableParsers[lookupType])),
            "markFilteringSet":
                useMarkFilteringSet != 0 ? this.parseUShort() : null
          };
        }))) ??
        [];
  }

  dynamic parsePointer32(description) {
    int structOffset = this.parseOffset32();
    if (structOffset > 0) {
      // NULL offset => return undefined
      return Parser(this.data, this.offset + structOffset)
          .parseStruct(description);
    }
    return null;
  }

  dynamic parseRecordList32(int count, dynamic recordDescription) {
    // If the count argument is absent, read it in the stream.
    if (count == null) {
      count = this.parseULong();
    }
    List<dynamic> records = List(count);
    List<dynamic> fields =
        (recordDescription as Map<String, dynamic>).keys.toList();
    for (int i = 0; i < count; i++) {
      Map<String, dynamic> rec = {};
      for (int j = 0; j < fields.length; j++) {
        String fieldName = fields[j];
        dynamic fieldType = recordDescription[fieldName];
        rec[fieldName] = fieldType.call(this);
      }
      records[i] = rec;
    }
    return records;
  }

  dynamic parseFeatureVariationsList() {
    return this.parsePointer32(() {
          int majorVersion = this.parseUShort();
          int minorVersion = this.parseUShort();
          //check.argument(majorVersion === 1 && minorVersion < 1, 'GPOS/GSUB feature variations table unknown.');
          int featureVariations = this.parseRecordList32(null, {
            "conditionSetOffset": parseOffset32,
            "featureTableSubstitutionOffset": parseOffset32
          });
          return featureVariations;
        }) ??
        [];
  }
}
