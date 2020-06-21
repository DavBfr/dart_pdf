part of pdf;

class GsubTableParser {
  Map<int, String> LookupTypes = {
    1: 'single',
    2: 'multiple',
    3: 'alternate',
    4: 'ligature',
    5: 'contextual',
    6: 'chaining',
    7: 'extension',
    8: 'reverse'
  };

  // https://www.microsoft.com/typography/OTSPEC/gsub.htm
  parseGsubTable(UnmodifiableByteDataView bytes, int start) {
    start = start ?? 0;

    ReadBuffer table = ReadBuffer(ByteData.sublistView(bytes, start), 0);
    //table.goto(start);

    var data = Map<String, dynamic>();

    var version = table.read(ReadTyps[Types.FIXED]);
    var scriptListOffset = table.read(ReadTyps[Types.OFFSET]);
    var featureListOffset = table.read(ReadTyps[Types.OFFSET]);
    var lookupListOffset = table.read(ReadTyps[Types.OFFSET]);

    var scriptList = ParseList(table, scriptListOffset, Script, "table");
    var featureList = ParseList(table, featureListOffset, Feature, "table");
    var lookupList = LookupList(table, lookupListOffset, LookupType);

    data["script"] = scriptList;
    data["feature"] = featureList;
    data["lookup"] = lookupList;

    scriptList.forEach((script) {
      var scriptTag = script["tag"];
      var scriptTable = script["table"];

      data[scriptTag] = Map<dynamic, dynamic>();

      scriptTable.forEach((language) {
        var languageTag = language["tag"];
        var languageTable = language["table"];

        data[scriptTag][languageTag] = Map<dynamic, dynamic>();

        languageTable["FeatureIndex"].forEach((featureIndex) {
          var feature = featureList[featureIndex];
          var featureTag = feature["tag"];
          var featureTable = feature["table"];

          data[scriptTag][languageTag][featureTag] = Map<dynamic, dynamic>();

          featureTable["LookupListIndex"].forEach((lookupIndex) {
            var lookup = lookupList[lookupIndex];
            var type = LookupTypes[lookup["LookupType"]];

            data[scriptTag][languageTag][featureTag][type] =
                Map<dynamic, dynamic>();

            lookup["SubTable"].forEach((subTable) {
              subTable.keys.forEach((glyphId) {
                data[scriptTag][languageTag][featureTag][type][glyphId] =
                    subTable[glyphId];
              });
            });
          });
        });
      });
    });

    print("ss");
    return data;
  }

  SubstLookupRecord() => utilstruct({
        "SequenceIndex": ReadTyps[Types.USHORT],
        "LookupListIndex": ReadTyps[Types.USHORT]
      });

  LookupType(buffer, lookupType, offset) {
    buffer.goto(offset);

    var format = buffer.read(ReadTyps[Types.USHORT]);
    var data = Map<dynamic, dynamic>();
    /**
     * substitution: {
     *   single: {
     *     "A": "A-caret"
     *   },
     *   multiple: {
     *     "A": ["A-caret", "A-long"]
     *   },
     *   alternate: {
     *     "A": ["A-single", "A-multi"]
     *   },
     *   ligature: {
     *     "f": [
     *      { components: ["i"], ligature: "fi" },
     *      { components: ["f"], ligature: "ff" },
     *      { components: ["f", "i"], ligature: "ffi" },
     *      { components: ["f", "l"], ligature: "ffl" },
     *      { components: ["l"], ligature: "fl" }
     *     ],
     *     "e": [
     *       ...
     *     ]
     *   },
     *   contextual: {
     *     "f"
     *   }
     * }
     */

    if (lookupType == 1 && format == 1) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var deltaGlyphId = buffer.read(ReadTyps[Types.SHORT]);
      var coverage = Coverage(buffer, offset + coverageOffset);
//      //{ format: 1, "list":[]}
//      var covData = Map<dynamic, dynamic>();
//      for (var i = 0; i < coverage["list"].length; i += 1) {
//        covData[coverage["list"][i]] = coverage["list"][i] + deltaGlyphId;
//      }
      data["deltaGlyphId"] = deltaGlyphId;
      data["coverage"] = {
        "format": coverage["format"],
        getCoveragekey(coverage["format"]): coverage["list"]
      };
    } else if (lookupType == 1 && format == 2) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
      var substitutes = buffer.readArray(ReadTyps[Types.GLYPHID], glyphCount);
      var coverage = Coverage(buffer, offset + coverageOffset);

//      for (var i = 0; i < coverage.length; i += 1) {
//        data[coverage[i]] = substitutes[i];
//      }

//      //{ format: 1, "list":[]}
//      var covData = Map<dynamic, dynamic>();
//      for (var i = 0; i < coverage["list"].length; i += 1) {
//        covData[coverage["list"][i]] = substitutes[i];
//      }
      data["substitute"] = substitutes;
      data["coverage"] = {
        "format": coverage["format"],
        getCoveragekey(coverage["format"]): coverage["list"]
      };
    } else if (lookupType == 2 || lookupType == 3) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var count = buffer.read(ReadTyps[Types.USHORT]);

      var setOffsets = buffer.readArray(ReadTyps[Types.OFFSET], count);
      var coverage = Coverage(buffer, offset + coverageOffset);
      var sets = [];

      for (var i = 0; i < count; i += 1) {
        buffer.goto(offset + setOffsets[i]);
        var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
        sets.add(buffer.readArray(ReadTyps[Types.GLYPHID], glyphCount));
      }

//      for (var i = 0; i < coverage.length; i += 1) {
//        if (lookupType == 2) {
//          data[coverage[i]] = sets[i];
//        } else {
//          data[coverage[i]] = sets[i];
//        }
//      }

      //{ format: 1, "list":[]}
      var covData = Map<dynamic, dynamic>();
      for (var i = 0; i < coverage["list"].length; i += 1) {
        if (lookupType == 2) {
          covData[coverage["list"][i]] = sets[i];
        } else {
          covData[coverage["list"][i]] = sets[i];
        }
      }

      data["coverage"] = {
        "format": coverage["format"],
        getCoveragekey(coverage["format"]): covData
      };
    } else if (lookupType == 4) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var count = buffer.read(ReadTyps[Types.USHORT]);

      var setOffsets = buffer.readArray(ReadTyps[Types.OFFSET], count);
      var coverage = Coverage(buffer, offset + coverageOffset);
      var ligatureSetOffsets = [];

      for (var i = 0; i < count; i += 1) {
        buffer.goto(offset + setOffsets[i]);
        var ligatureCount = buffer.read(ReadTyps[Types.USHORT]);
        ligatureSetOffsets
            .add(buffer.readArray(ReadTyps[Types.OFFSET], ligatureCount));
      }

      List<dynamic> ligatureSet = [];

      for (var i = 0; i < setOffsets.length; i += 1) {
        List<Map<dynamic, dynamic>> ligature = [];

        for (var j = 0; j < ligatureSetOffsets[i].length; j += 1) {
          buffer.goto(offset + setOffsets[i] + ligatureSetOffsets[i][j]);
          var ligGlyph = buffer.read(ReadTyps[Types.GLYPHID]);
          var components = buffer.readArray(
              ReadTyps[Types.GLYPHID], buffer.read(ReadTyps[Types.USHORT]) - 1);

          ligature.add({"ligature": ligGlyph, "components": components});
        }
        ligatureSet.add(ligature);
      }

//      for (var i = 0; i < coverage.length; i += 1) {
//        data[coverage[i]] = ligatureSet[i];
//      }

      //{ format: 1, "list":[]}
//      var covData = Map<dynamic, dynamic>();
//      for (var i = 0; i < coverage["list"].length; i += 1) {
//        covData[coverage["list"][i]] = ligatureSet[i];
//      }
      data["ligatureSets"] = ligatureSet;
      data["coverage"] = {
        "format": coverage["format"],
        getCoveragekey(coverage["format"]): coverage["list"]
      };
    } else if (lookupType == 5 && format == 1) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var subRuleSetCount = buffer.read(ReadTyps[Types.USHORT]);
      var subRuleSetOffsets =
          buffer.readArray(ReadTyps[Types.OFFSET], subRuleSetCount);

      var coverage = Coverage(buffer, offset + coverageOffset);

      subRuleSetOffsets.forEach((subRuleSetOffset) {
        buffer.goto(offset + subRuleSetOffset);
        var subRuleCount = buffer.read(ReadTyps[Types.USHORT]);
        var subRuleOffsets =
            buffer.readArray(ReadTyps[Types.OFFSET], subRuleCount);

        subRuleOffsets.forEach((subRuleOffset) {
          buffer.goto(offset + subRuleSetOffset + subRuleOffset);

          var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
          var substCount = buffer.read(ReadTyps[Types.USHORT]);
          var input = buffer.readArray(ReadTyps[Types.GLYPHID], glyphCount - 1);
          var records = buffer.readArray(SubstLookupRecord, substCount);

//          for (var i = 0; i < coverage.length; i++) {
//            if (!data[coverage[i]]) {
//              data[coverage[i]] = [];
//            }
//
//            data[coverage[i]].push({"input": input, "records": records});
//          }

          //{ format: 1, "list":[]}
          var covData = Map<dynamic, dynamic>();
          for (var i = 0; i < coverage["list"].length; i += 1) {
            if (covData[coverage["list"][i]] == null) {
              covData[coverage["list"][i]] = [];
            }
            covData[coverage["list"][i]]
                .push({"input": input, "records": records});
          }

          data["coverage"] = {
            "format": coverage["format"],
            getCoveragekey(coverage["format"]): covData
          };
        });
      });
    } else if (lookupType == 5 && format == 2) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var classDefOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var subClassSetCount = buffer.read(ReadTyps[Types.USHORT]);
      var subClassSetOffsets =
          buffer.readArray(ReadTyps[Types.OFFSET], subClassSetCount);

      var coverage = Coverage(buffer, offset + coverageOffset);
      var classDef = ClassDef(buffer, offset + classDefOffset);

      subClassSetOffsets.forEach((subClassSetOffset) {
        buffer.goto(offset + subClassSetOffset);

        var subClassRuleCount = buffer.read(ReadTyps[Types.USHORT]);
        var subClassRuleOffsets =
            buffer.readArray(ReadTyps[Types.OFFSET], subClassRuleCount);

        subClassRuleOffsets.forEach((subClassRuleOffset) {
          buffer.goto(offset + subClassSetOffset + subClassRuleOffset);

          var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
          var substCount = buffer.read(ReadTyps[Types.USHORT]);
          var classes =
              buffer.readArray(ReadTyps[Types.USHORT], glyphCount - 1);
          var records = buffer.readArray(SubstLookupRecord, substCount);
        });
      });
    } else if (lookupType == 5 && format == 3) {
      var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
      var substCount = buffer.read(ReadTyps[Types.USHORT]);
      var coverageOffsets =
          buffer.readArray(ReadTyps[Types.OFFSET], glyphCount);
      var records = buffer.readArray(SubstLookupRecord, substCount);

      coverageOffsets.forEach((coverageOffset) {
        var coverage = Coverage(buffer,
            offset + coverageOffset); // TODO check coverage variable use
      });
    } else if (lookupType == 6 && format == 1) {
    } else if (lookupType == 6 && format == 2) {
    } else if (lookupType == 6 && format == 3) {
    } else if (lookupType == 7) {
      var extensionLookupType = buffer.read(ReadTyps[Types.USHORT]);
      var extensionOffset = buffer.read(ReadTyps[Types.ULONG]);
      data = LookupType(buffer, extensionLookupType, offset + extensionOffset);
    } else if (lookupType == 8 && format == 1) {
      var coverageOffset = buffer.read(ReadTyps[Types.OFFSET]);
      var backtrackGlyphCount = buffer.read(ReadTyps[Types.USHORT]);
      var backtrackCoverageOffsets =
          buffer.readArray(ReadTyps[Types.OFFSET], backtrackGlyphCount);
      var lookaheadGlyphCount = buffer.read(ReadTyps[Types.USHORT]);
      var lookaheadCoverageOffsets =
          buffer.readArray(ReadTyps[Types.OFFSET], lookaheadGlyphCount);
      var glyphCount = buffer.read(ReadTyps[Types.USHORT]);
      var substitutes = buffer.readArray(ReadTyps[Types.GLYPHID], glyphCount);
    }

    data["substFormat"] = format;
    return data;
  }
}

String getCoveragekey(format) {
  return format == 1 ? "glyphs" : "ranges";
}
