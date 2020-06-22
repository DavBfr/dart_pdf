part of pdf;

/**
 * Update context params
 * @param {any} tokens a list of tokens
 * @param {number} index current item index
 */
dynamic getContextParams(List<Token> tokens, [index]) {
  List<dynamic> context = tokens
      .map((token) => token.activeState["value"])
      .toList()
      .cast<dynamic>();
  return ContextParams(context, index ?? 0);
}

/**
 * Apply Arabic required ligatures to a context range
 * @param {ContextRange} range a range of tokens
 */
dynamic devnagriLigature(range, Bidi bidi, String tag) {
  const script = 'dev2';
  var tokens = bidi.tokenizer.getRangeTokens(range);
  var contextParams = getContextParams(tokens);

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
      contextParams = getContextParams(tokens);
    }
  });
}

/**
 * Check if a char can be connected to it's preceding char
 * @param {ContextParams} charContextParams context params of a char
 */
dynamic willConnectPrevDev(charContextParams) {
  var backtrack = [...(charContextParams.backtrack)];
  for (int i = backtrack.length - 1; i >= 0; i--) {
    var prevChar = backtrack[i];
    var isolated = isIsolatedArabicChar(prevChar);
    var tashkeel = isTashkeelArabicChar(prevChar);
    if (!isolated && !tashkeel) {
      return true;
    }
    if (isolated) {
      return false;
    }
  }
  return false;
}

/**
 * Check if a char can be connected to it's proceeding char
 * @param {ContextParams} charContextParams context params of a char
 */
dynamic willConnectNextDev(charContextParams) {
  if (isIsolatedArabicChar(charContextParams.current)) {
    return false;
  }
  for (int i = 0; i < charContextParams.lookahead.length; i++) {
    var nextChar = charContextParams.lookahead[i];
    var tashkeel = isTashkeelArabicChar(nextChar);
    if (!tashkeel) {
      return true;
    }
  }
  return false;
}

/**
 * Apply arabic presentation forms to a list of tokens
 * @param {ContextRange} range a range of tokens
 */
dynamic devnagaraiPresentationForms(range, Bidi bidi) {
  var script = 'dev2';
  var tags = bidi.featuresTags[script];
  var tokens = bidi.tokenizer.getRangeTokens(range);
  if (tokens.length == 1) {
    return;
  }
  var contextParams =
      new ContextParams(tokens.map((token) => token.getState('glyphIndex')), 0);
  var charContextParams = ContextParams(tokens.map((token) => token.char).toList(), 0);
  tokens.forEach((token, index) {
    if (isTashkeelArabicChar(token.char)) {
      return;
    }
    contextParams.setCurrentIndex(index);
    charContextParams.setCurrentIndex(index);
    var CONNECT = 0; // 2 bits 00 (10: can connect next) (01: can connect prev)
    if (willConnectPrevDev(charContextParams)) {
      CONNECT |= 1;
    }
    if (willConnectNextDev(charContextParams)) {
      CONNECT |= 2;
    }
    String tag;
    switch (CONNECT) {
      case 1:
        (tag = 'fina');
        break;
      case 2:
        (tag = 'init');
        break;
      case 3:
        (tag = 'medi');
        break;
    }
    if (tags.indexOf(tag) == -1) {
      return;
    }
    var featureQuery = FeatureQuery(bidi.query.font)
      ..tag = tag
      ..script = script
      ..contextParams = contextParams;

    var substitutions = bidi.query.lookupFeature(featureQuery);

    if (substitutions is Error) {
      return print("Errir in arab ligature");
    }

    substitutions.forEach((action, index) {
      if (action is SubstitutionAction) {
        applySubstitution(action, tokens, index);
        contextParams.context[index] = action.substitution;
      }
    });
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
