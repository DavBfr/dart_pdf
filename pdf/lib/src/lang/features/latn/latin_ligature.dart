part of pdf;

/**
 * Update context params
 * @param {any} tokens a list of tokens
 * @param {number} index current item index
 */
dynamic getContextParamsLatin(tokens, [index]) {
  var context = tokens.map((token) => token.activeState["value"]);
  return ContextParams(context, index ?? 0);
}

/**
 * Apply Arabic required ligatures to a context range
 * @param {ContextRange} range a range of tokens
 */
dynamic latinLigature(range, Bidi bidi) {
  const script = 'latn';
  var tokens = bidi.tokenizer.getRangeTokens(range);
  var contextParams = getContextParamsLatin(tokens);
  contextParams.context.forEach((glyphIndex, index) {
    contextParams.setCurrentIndex(index);
    var featureQuery = FeatureQuery(bidi.query.font)
      ..tag = "liga"
      ..script = script
      ..contextParams = contextParams;
    var substitutions = bidi.query.lookupFeature(featureQuery);
    if (substitutions.length) {
      substitutions
          .forEach((action) => applySubstitution(action, tokens, index));
      contextParams = getContextParamsLatin(tokens);
    }
  });
}

dynamic latinWordStartCheck(ContextParams contextParams) {
  var char = contextParams.current;
  var prevChar = contextParams.get(-1);
  return
      // ? latin first char
      (prevChar == null && isLatinChar(char)) ??
          // ? latin char preceded with a non latin char
          (!isLatinChar(prevChar) && isLatinChar(char));
}

dynamic latinWordEndCheck(ContextParams contextParams) {
  var nextChar = contextParams.get(1);
  return
      // ? last latin char
      (nextChar == null) ??
          // ? next char is not latin
          (!isLatinChar(nextChar));
}

class LatinWordCheck {
  get startCheck => latinWordStartCheck;
  get endCheck => latinWordEndCheck;
}
