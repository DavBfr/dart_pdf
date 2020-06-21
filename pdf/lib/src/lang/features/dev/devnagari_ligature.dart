part of pdf;

/**
 * Update context params
 * @param {any} tokens a list of tokens
 * @param {number} index current item index
 */
dynamic getContextParamsDev(List<Token> tokens, [index]) {
  List<dynamic> context =
      tokens.map((token) => token.activeState["value"]).toList().cast<dynamic>();
  return ContextParams(context, index ?? 0);
}

/**
 * Apply Arabic required ligatures to a context range
 * @param {ContextRange} range a range of tokens
 */
dynamic devnagriLigature(range, Bidi bidi, String tag) {
  const script = 'dev2';
  var tokens = bidi.tokenizer.getRangeTokens(range);
  var contextParams = getContextParamsDev(tokens);

  List.generate(contextParams.context.length, (index) {
    var glyphIndex = contextParams.context[index];
    contextParams.setCurrentIndex(index);
    var featureQuery = FeatureQuery(bidi.query.font)
      ..tag = tag
      ..script = script
      ..contextParams = contextParams;
    var substitutions = bidi.query.lookupFeature(featureQuery);
    if (substitutions?.isNotEmpty ?? false) {
      substitutions
          .forEach((action) => applySubstitution(action, tokens, index));
      contextParams = getContextParamsDev(tokens);
    }
  });
}

dynamic devnagriWordStartCheck(ContextParams contextParams) {
  var char = contextParams.current;
  var prevChar = contextParams.get(-1);
  return
      // ? latin first char
      (prevChar == null && isDevnagariChar(char)) ??
          // ? latin char preceded with a non latin char
          (!isDevnagariChar(prevChar) && isDevnagariChar(char));
}

dynamic devnagriWordEndCheck(ContextParams contextParams) {
  var nextChar = contextParams.get(1);
  return
      // ? last latin char
      (nextChar == null) ??
          // ? next char is not latin
          (!isDevnagariChar(nextChar));
}

class DevnagariWordCheck {
  get startCheck => devnagriWordStartCheck;
  get endCheck => devnagriWordEndCheck;
}
