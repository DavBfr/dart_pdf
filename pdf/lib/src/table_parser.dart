part of pdf;

dynamic ParseList(ReadBuffer buffer, int offset, table, String mainTag) {
  buffer.goto(offset);

  var data = [];
  var count = buffer.read(ReadTyps[Types.USHORT]);

  var records = buffer.readArray(
      utilstruct(
          {"tag": ReadTyps[Types.TAG], "offset": ReadTyps[Types.OFFSET]}),
      count);

  for (var i = 0; i < count; i += 1) {
    data.add({
      "tag": records[i]["tag"],
      mainTag: table(buffer, offset + records[i]["offset"])
    });
  }

  return data;
}

dynamic ClassDef(ReadBuffer buffer, int offset) {
  buffer.goto(offset);

  var format = buffer.read(ReadTyps[Types.USHORT]);
  var data = Map<dynamic, dynamic>();

  if (format == 1) {
    var startGlyph = buffer.read(ReadTyps[Types.GLYPHID]);
    var classValues = buffer.readArray(
        ReadTyps[Types.USHORT], buffer.read(ReadTyps[Types.USHORT]));

    for (var i = startGlyph, j = 0;
        i < (startGlyph + classValues.length);
        i++, j++) {
      data[i] = classValues[j];
    }
  } else if (format == 2) {
    var classRangeRecords = buffer.readArray(
        utilstruct({
          "Start": ReadTyps[Types.GLYPHID],
          "End": ReadTyps[Types.GLYPHID],
          "Class": ReadTyps[Types.USHORT]
        }),
        buffer.read(ReadTyps[Types.USHORT]));

    classRangeRecords.forEach((record) {
      for (int i = record.Start; i <= record.End; i++) {
        data[i] = record.Class;
      }
    });
  }

  return data;
}

dynamic Script(ReadBuffer buffer, int offset) {
  buffer.goto(offset);

  var data = [];

  var defaultLangSys = buffer.read(ReadTyps[Types.OFFSET]);
  var langSysCount = buffer.read(ReadTyps[Types.USHORT]);

  var records = buffer.readArray(
    utilstruct({
      "tag": ReadTyps[Types.TAG],
      "offset": ReadTyps[Types.OFFSET],
    }),
    langSysCount,
  );

  if (defaultLangSys != null) {
    data.add(
      {"tag": 'DFLT', "table": LangSys(buffer, offset + defaultLangSys)},
    );
  }

  for (var i = 0; i < records.length; i += 1) {
    data.add({
      "tag": records[i]["tag"],
      "table": LangSys(buffer, offset + records[i]["offset"])
    });
  }

  return data;
}

dynamic LangSys(ReadBuffer buffer, int offset) {
  buffer.goto(offset);

  var lookupOrder = buffer.read(ReadTyps[Types.OFFSET]);
  var reqFeatureIndex = buffer.read(ReadTyps[Types.USHORT]);
  var featureCount = buffer.read(ReadTyps[Types.USHORT]);
  var featureIndex = buffer.readArray(ReadTyps[Types.USHORT], featureCount);

  return {
    'LookupOrder': lookupOrder,
    'ReqFeatureIndex': reqFeatureIndex,
    'FeatureCount': featureCount,
    'FeatureIndex': featureIndex
  };
}

dynamic Feature(ReadBuffer buffer, int offset) {
  buffer.goto(offset);

  var featureParams = buffer.read(ReadTyps[Types.OFFSET]);
  var lookupCount = buffer.read(ReadTyps[Types.USHORT]);
  var lookupListIndex = buffer.readArray(ReadTyps[Types.USHORT], lookupCount);

  return {
    'FeatureParams': featureParams,
    'LookupCount': lookupCount,
    'LookupListIndex': lookupListIndex
  };
}

dynamic LookupList(ReadBuffer buffer, int offset, dynamic table) {
  buffer.goto(offset);

  var data = [];
  var count = buffer.read(ReadTyps[Types.USHORT]);
  var records = buffer.readArray(ReadTyps[Types.OFFSET], count);

  for (var i = 0; i < count; i += 1) {
    data.add(Lookup(buffer, offset + records[i], table));
  }

  return data;
}

dynamic Lookup(ReadBuffer buffer, int offset, dynamic table) {
  buffer.goto(offset);

  var data = Map<dynamic, dynamic>();

  var lookupType = buffer.read(ReadTyps[Types.USHORT]);
  var lookupFlag = buffer.read(ReadTyps[Types.USHORT]);
  var subTableCount = buffer.read(ReadTyps[Types.USHORT]);
  var subTables = buffer.readArray(ReadTyps[Types.OFFSET], subTableCount);

  var markFilteringSet =
      (lookupFlag & 0x10) != 0 ? buffer.read(ReadTyps[Types.USHORT]) : null;

  for (var i = 0; i < subTableCount; i += 1) {
    subTables[i] = table(buffer, lookupType, offset + subTables[i]);
  }

  return {
    'LookupType': lookupType,
    'LookupFlag': lookupFlag,
    'SubTable': subTables,
    'MarkFilteringSet': markFilteringSet
  };
}

dynamic Coverage(ReadBuffer buffer, int offset) {
  buffer.goto(offset);

  var format = buffer.read(ReadTyps[Types.USHORT]);
  var count = buffer.read(ReadTyps[Types.USHORT]);
  List<dynamic> data = [];

  if (format == 1) {
    data = buffer.readArray(ReadTyps[Types.GLYPHID], count);
  } else if (format == 2) {
    var records = buffer.readArray(
        utilstruct({
          "start": ReadTyps[Types.GLYPHID],
          "end": ReadTyps[Types.GLYPHID],
          "startCoverageIndex": ReadTyps[Types.USHORT]
        }),
        count);

    for (var i = 0; i < count; i += 1) {
      data.add(records[i]);
//      for (var glyph = records[i]["start"];
//          glyph <= records[i]["end"];
//          glyph += 1) {
//        data.add(
//            records[i]["startCoverageIndex"] + glyph - records[i]["start"]);
//      }
    }
  }

  return {"format": format, "list": data};
}
