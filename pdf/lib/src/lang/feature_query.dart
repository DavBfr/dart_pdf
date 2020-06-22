part of pdf;

class FeatureQuery {
  final TtfParser font;
  Map<String, Map<String, dynamic>> features = {};
  String tag;
  String script;
  ContextParams contextParams;

  FeatureQuery(this.font, [this.script, this.tag]);

  /**
   * Get default script features indexes
   */
  dynamic getDefaultScriptFeaturesIndexes() {
    var scripts = this.font.gsubTables["script"];
    for (var s = 0; s < scripts.length; s++) {
      var script = scripts[s];

      var deaultBlk = script["table"].where((e) => e["tag"] == "DFLT").toList();
      return deaultBlk[0]["FeatureIndex"];
    }
    return [];
  }

  /**
   * Get feature indexes of a specific script
   * @param {string} scriptTag script tag
   */
  // data[scriptTag][languageTag][featureTag][type][glyphId]
  dynamic getScriptFeaturesIndexes(scriptTag) {
//    var tables = this.font.gsubTables;
//    if (tables == null) {
//      return [];
//    }
    if (scriptTag == null) {
      return this.getDefaultScriptFeaturesIndexes();
    }

    List<dynamic> scripts = this.font.gsubTables["script"];

    for (var i = 0; i < scripts.length; i++) {
      var script = scripts[i];
      if (script["tag"] == scriptTag && script["table"] != null) {
        return script["table"][0]["table"]["FeatureIndex"];
      } else {
        print("Will not go here");
//        var langSysRecords = script["langSysRecords"];
//        if (langSysRecords != null) {
//          for (var j = 0; j < langSysRecords.length; j++) {
//            var langSysRecord = langSysRecords[j];
//            if (langSysRecord["tag"] == scriptTag) {
//              var langSys = langSysRecord["langSys"];
//              return langSys["featureIndexes"];
//            }
//          }
//        }
      }
    }

    return this.getDefaultScriptFeaturesIndexes();
  }

  /**
   * Map a feature tag to a gsub feature
   * @param {any} features gsub features
   * @param {string} scriptTag script tag
   */
  dynamic mapTagsToFeatures(features, scriptTag) {
    var tags = {};
    for (var i = 0; i < features.length; i++) {
      var tag = features[i]["tag"];
      var feature = features[i]["table"];
      tags[tag] = feature;
    }
    this.features[scriptTag]["tags"] = tags;
  }

  /**
   * Get features of a specific script
   * @param {string} scriptTag script tag
   */
  dynamic getScriptFeatures(scriptTag) {
    var features = this.features[scriptTag];
    if (this.features.containsKey(scriptTag)) {
      return features;
    }
    var featuresIndexes = this.getScriptFeaturesIndexes(scriptTag);
    if (featuresIndexes == null) {
      return null;
    }
    var featuresList = this.font.gsubTables["feature"];
    var x = featuresIndexes.map((index) => featuresList[index]).toList();
    this.features[scriptTag] = {"list": x};
    this.mapTagsToFeatures(x, scriptTag);
    return x;
  }

  /**
   * Get substitution type
   * @param {any} lookupTable lookup table
   * @param {any} subtable subtable
   */
  dynamic getSubstitutionType(lookupTable, subtable) {
    var lookupType = lookupTable["LookupType"].toString();
    var substFormat = subtable["substFormat"].toString();
    return lookupType + substFormat;
  }

  /**
   * Get lookup method
   * @param {any} lookupTable lookup table
   * @param {any} subtable subtable
   */
  dynamic getLookupMethod(lookupTable, subtable) {
    String substitutionType = this.getSubstitutionType(lookupTable, subtable);
    switch (substitutionType) {
      case '11':
        return (glyphIndex) => singleSubstitutionFormat1(glyphIndex, subtable);
      case '12':
        return (glyphIndex) => singleSubstitutionFormat2(glyphIndex, subtable);
      case '63':
        return (contextParams) =>
            chainingSubstitutionFormat3(contextParams, subtable);
      case '41':
        return (contextParams) =>
            ligatureSubstitutionFormat1(contextParams, subtable);
      case '71':
        return (contextParams) =>
            singleSubstitutionFormat1(contextParams, subtable);
      case '21':
        return (glyphIndex) =>
            decompositionSubstitutionFormat1(glyphIndex, subtable);
      default:
        throw Exception(""" 
        lookupType: ${lookupTable.lookupType}
        substFormat: ${subtable.substFormat}  
        is not yet supported 
        """);
    }
  }

  /**
   * [ LOOKUP TYPES ]
   * -------------------------------
   * Single                        1;
   * Multiple                      2;
   * Alternate                     3;
   * Ligature                      4;
   * Context                       5;
   * ChainingContext               6;
   * ExtensionSubstitution         7;
   * ReverseChainingContext        8;
   * -------------------------------
   *
   */

  /**
   * @typedef FQuery
   * @type Object
   * @param {string} tag feature tag
   * @param {string} script feature script
   * @param {ContextParams} contextParams context params
   */

  /**
   * Lookup a feature using a query parameters
   * @param {FQuery} query feature query
   */
  dynamic lookupFeature(FeatureQuery query) {
    var contextParams = query.contextParams;
    var currentIndex = contextParams.index;

    var feature = this.getFeature(query);
    if (feature == null) {
      return Exception("""font '${this.font} ahaha'
    doesn't support feature '${query.tag}'
    for script '${query.script}'""");
    }
    var lookups = this.getFeatureLookups(feature);
    List<dynamic> substitutions = [...contextParams.context];
    for (var l = 0; l < lookups.length; l++) {
      var lookupTable = lookups[l];
      var subtables = this.getLookupSubtables(lookupTable);
      for (var s = 0; s < subtables.length; s++) {
        var subtable = subtables[s];
        var substType = this.getSubstitutionType(lookupTable, subtable);
        var lookup = this.getLookupMethod(lookupTable, subtable);
        var substitution;
        switch (substType) {
          case '11':
            substitution = lookup(contextParams.current);
            if (substitution) {
              substitutions.replaceRange(
                currentIndex,
                currentIndex + 1,
                [
                  SubstitutionAction({
                    "id": 11,
                    "tag": query.tag,
                    "substitution": substitution
                  })
                ],
              );
            }
            break;
          case '12':
            substitution = lookup(contextParams.current);
            if (substitution) {
              substitutions.replaceRange(currentIndex, currentIndex + 1, [
                SubstitutionAction(
                    {"id": 12, "tag": query.tag, "substitution": substitution})
              ]);
            }
            break;
          case '63':
            substitution = lookup(contextParams);
            if (substitution is List && substitution.length > 0) {
              substitutions.replaceRange(currentIndex, currentIndex + 1, [
                SubstitutionAction(
                    {"id": 63, "tag": query.tag, "substitution": substitution})
              ]);
            }
            break;
          case '41':
            substitution = lookup(contextParams);
            if (substitution != null) {
              substitutions.replaceRange(currentIndex, currentIndex + 1, [
                SubstitutionAction(
                    {"id": 41, "tag": query.tag, "substitution": substitution})
              ]);
            }
            break;
          case '71':
            substitution = lookup(contextParams);
            if (substitution != null) {
              substitutions.replaceRange(currentIndex, currentIndex + 1, [
                SubstitutionAction(
                    {"id": 71, "tag": query.tag, "substitution": substitution})
              ]);
            }
            break;
          case '21':
            substitution = lookup(contextParams.current);
            if (substitution != null) {
              substitutions.replaceRange(currentIndex, currentIndex + 1, [
                SubstitutionAction(
                    {"id": 21, "tag": query.tag, "substitution": substitution})
              ]);
            }
            break;
        }
        contextParams = new ContextParams(substitutions, currentIndex);
        if (substitution is List && !substitution.isEmpty) {
          continue;
        }
        substitution = null;
      }
    }
    return substitutions.isNotEmpty ? substitutions : null;
  }

  /**
   * Checks if a font supports a specific features
   * @param {FQuery} query feature query object
   */
  dynamic supports(FeatureQuery query) {
    if (query.script == null) {
      return false;
    }
    this.getScriptFeatures(query.script);
    var supportedScript = this.features.containsKey(query.script);
    if (query.tag == null) {
      return supportedScript;
    }
    var supportedFeature = (this.features[query.script]["list"] as List)
        .firstWhere((feature) => feature["tag"] == query.tag,
            orElse: () => null);
    return supportedScript && supportedFeature != null;
  }

  /**
   * Get lookup table subtables
   * @param {any} lookupTable lookup table
   */
  List<dynamic> getLookupSubtables(Map<String, dynamic> lookupTable) {
    return lookupTable["SubTable"] ?? null;
  }

  /**
   * Get lookup table by index
   * @param {number} index lookup table index
   */
  dynamic getLookupByIndex(index) {
    var lookups = this.font.gsubTables["lookup"];
    return lookups[index] ?? null;
  }

  /**
   * Get lookup tables for a feature
   * @param {string} feature
   */
  dynamic getFeatureLookups(Map<String, dynamic> feature) {
    // TODO: memoize
    return feature["LookupListIndex"]
        .map((s) => this.getLookupByIndex(s))
        .toList();
  }

  /**
   * Query a feature by it's properties
   * @param {any} query an object that describes the properties of a query
   */
  dynamic getFeature(FeatureQuery query) {
    if (this.font == null) {
      return null;
    }
    if (!this.features.containsKey(query.script)) {
      this.getScriptFeatures(query.script);
    }
    var scriptFeatures = this.features[query.script];
    if (scriptFeatures == null) {
      return null;
    }
    if (scriptFeatures["tags"][query.tag] == null) {
      return null;
    }
    return this.features[query.script]["tags"][query.tag];
  }

  /**
   * Handle chaining context substitution - format 3
   * @param {ContextParams} contextParams context params to lookup
   */
  dynamic chainingSubstitutionFormat3(ContextParams contextParams, subtable) {
    int lookupsCount = subtable["inputCoverage"].length +
        subtable["lookaheadCoverage"].length +
        subtable["backtrackCoverage"].length;
    if (contextParams.context.length < lookupsCount) {
      return [];
    }
    // INPUT LOOKUP //
    var inputLookups =
        lookupCoverageList(subtable["inputCoverage"], contextParams);
    if (inputLookups == -1) {
      return [];
    }
    // LOOKAHEAD LOOKUP //
    var lookaheadOffset = subtable["inputCoverage"].length - 1;
    if (contextParams.lookahead.length < subtable["lookaheadCoverage"].length)
      return [];
    var lookaheadContext = contextParams.lookahead.sublist(lookaheadOffset);
    while (lookaheadContext.isNotEmpty &&
        isTashkeelArabicChar(lookaheadContext[0])) {
      lookaheadContext.removeAt(0);
    }
    var lookaheadParams = ContextParams(lookaheadContext, 0);
    var lookaheadLookups =
        lookupCoverageList(subtable["lookaheadCoverage"], lookaheadParams);
    // BACKTRACK LOOKUP //
    List<String> backtrackContext = [...contextParams.backtrack];
    backtrackContext = backtrackContext.reversed.toList();
    while (backtrackContext.isNotEmpty &&
        isTashkeelArabicChar(backtrackContext[0])) {
      backtrackContext.removeAt(0);
    }
    if (backtrackContext.length < subtable["backtrackCoverage"].length) {
      return [];
    }
    var backtrackParams = ContextParams(backtrackContext, 0);
    var backtrackLookups =
        lookupCoverageList(subtable["backtrackCoverage"], backtrackParams);
    var contextRulesMatch =
        inputLookups.length == subtable["inputCoverage"].length &&
            lookaheadLookups.length == subtable["lookaheadCoverage"].length &&
            backtrackLookups.length == subtable["backtrackCoverage"].length;
    var substitutions = [];
    if (contextRulesMatch) {
      for (var i = 0; i < subtable["lookupRecords"].length; i++) {
        var lookupRecord = subtable["lookupRecords"][i];
        var lookupListIndex = lookupRecord.lookupListIndex;
        var lookupTable = this.getLookupByIndex(lookupListIndex);
        for (var s = 0; s < lookupTable.subtables.length; s++) {
          var subtable = lookupTable.subtables[s];
          var lookup = this.getLookupMethod(lookupTable, subtable);
          var substitutionType =
              this.getSubstitutionType(lookupTable, subtable);
          if (substitutionType == '12') {
            for (var n = 0; n < inputLookups.length; n++) {
              var glyphIndex = contextParams.get(n);
              var substitution = lookup(glyphIndex);
              if (substitution != null) {
                substitutions.add(substitution);
              }
            }
          }
        }
      }
    }
    return substitutions;
  }
}

/**
 * @typedef SubstitutionAction
 * @type Object
 * @property {number} id substitution type
 * @property {string} tag feature tag
 * @property {any} substitution substitution value(s)
 */

/**
 * Create a substitution action instance
 * @param {SubstitutionAction} action
 */
class SubstitutionAction {
  dynamic id;

  dynamic tag;

  dynamic substitution;

  SubstitutionAction(dynamic action) {
    this.id = action["id"];
    this.tag = action["tag"];
    this.substitution = action["substitution"];
  }
}

/**
 * Lookup a coverage table
 * @param {number} glyphIndex glyph index
 * @param {CoverageTable} coverage coverage table
 */
dynamic lookupCoverage(glyphIndex, coverage) {
  if (glyphIndex == null || coverage == null) {
    return -1;
  }
  switch (coverage["format"]) {
    case 1:
      return coverage["glyphs"].indexOf(glyphIndex);

    case 2:
      var ranges = coverage["ranges"];
      for (var i = 0; i < ranges.length; i++) {
        var range = ranges[i];
        if (range["start"] is int && range["end"] is int && glyphIndex is int) {
          if (glyphIndex >= range["start"] && glyphIndex <= range["end"]) {
            var offset = glyphIndex - range["start"];
            return range["startCoverageIndex"] + offset;
          }
        }
      }
      break;
    default:
      return -1; // not found
  }
  return -1;
}

/**
 * Handle a single substitution - format 1
 * @param {ContextParams} contextParams context params to lookup
 */
dynamic singleSubstitutionFormat1(glyphIndex, subtable) {
  var substituteIndex = lookupCoverage(glyphIndex, subtable["coverage"]);
  if (substituteIndex == -1) {
    return null;
  }
  return glyphIndex +
      subtable["deltaGlyphId"]; //TODO: check delta glyph id alrady handled diff
}

/**
 * Handle a single substitution - format 2
 * @param {ContextParams} contextParams context params to lookup
 */
dynamic singleSubstitutionFormat2(glyphIndex, subtable) {
  var substituteIndex = lookupCoverage(glyphIndex, subtable["coverage"]);
  if (substituteIndex == -1) {
    return null;
  }
  return subtable["substitute"][substituteIndex];
}

/**
 * Lookup a list of coverage tables
 * @param {any} coverageList a list of coverage tables
 * @param {ContextParams} contextParams context params to lookup
 */
dynamic lookupCoverageList(coverageList, contextParams) {
  List<dynamic> lookupList = [];
  for (var i = 0; i < coverageList.length; i++) {
    var coverage = coverageList[i];
    var glyphIndex = contextParams.current;
    glyphIndex = glyphIndex is List ? glyphIndex[0] : glyphIndex;
    var lookupIndex = lookupCoverage(glyphIndex, coverage);
    if (lookupIndex != -1) {
      lookupList.add(lookupIndex);
    }
  }
  if (lookupList.length != coverageList.length) {
    return -1;
  }
  return lookupList;
}

/**
 * Handle ligature substitution - format 1
 * @param {ContextParams} contextParams context params to lookup
 */
dynamic ligatureSubstitutionFormat1(ContextParams contextParams, subtable) {
  // COVERAGE LOOKUP //
  var glyphIndex = contextParams.current;
  var ligSetIndex = lookupCoverage(glyphIndex, subtable["coverage"]);
  if (ligSetIndex == -1) {
    return null;
  }
  // COMPONENTS LOOKUP
  // (!) note, components are ordered in the written direction.
  var ligature;
  var ligatureSet = subtable["ligatureSets"][ligSetIndex];
  for (var s = 0; s < ligatureSet.length; s++) {
    ligature = ligatureSet[s];
    for (var l = 0; l < ligature["components"].length; l++) {
      var lookaheadItem = contextParams.lookahead[l];
      var component = ligature["components"][l];
      if (lookaheadItem != component) {
        break;
      }
      if (l == ligature["components"].length - 1) {
        return ligature;
      }
    }
  }
  return null;
}

/**
 * Handle decomposition substitution - format 1
 * @param {number} glyphIndex glyph index
 * @param {any} subtable subtable
 */
dynamic decompositionSubstitutionFormat1(glyphIndex, subtable) {
  var substituteIndex = lookupCoverage(glyphIndex, subtable["coverage"]);
  if (substituteIndex == -1) {
    return null;
  }
  return subtable["sequences"][substituteIndex];
}
