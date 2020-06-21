part of pdf;

/**
 * Update context params
 * @param {any} tokens a list of tokens
 * @param {number} index current item index
 */
dynamic getContextParamsArab(tokens, [index]) {
  var context = tokens.map((token) => token.activeState["value"]);
  return ContextParams(context, index ?? 0);
}

/**
 * Apply Arabic required ligatures to a context range
 * @param {ContextRange} range a range of tokens
 */
dynamic arabicRequiredLigatures(range, Bidi bidi) {
  var script = 'arab';
  var tokens = bidi.tokenizer.getRangeTokens(range);
  var contextParams = getContextParamsArab(tokens);
  contextParams.context.forEach((glyphIndex, index) {
    contextParams.setCurrentIndex(index);
    var featureQuery = FeatureQuery(bidi.query.font)
      ..tag = "rlig"
      ..script = script
      ..contextParams = contextParams;

    var substitutions = bidi.query.lookupFeature(featureQuery);
    if (substitutions.length) {
      substitutions
          .forEach((action) => applySubstitution(action, tokens, index));
      contextParams = getContextParamsArab(tokens);
    }
  });
}

/**
 * Check if a char can be connected to it's preceding char
 * @param {ContextParams} charContextParams context params of a char
 */
dynamic willConnectPrev(charContextParams) {
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
dynamic willConnectNext(charContextParams) {
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
dynamic arabicPresentationForms(range, Bidi bidi) {
  var script = 'arab';
  var tags = bidi.featuresTags[script];
  var tokens = bidi.tokenizer.getRangeTokens(range);
  if (tokens.length == 1) {
    return;
  }
  var contextParams =
      new ContextParams(tokens.map((token) => token.getState('glyphIndex')), 0);
  var charContextParams = ContextParams(tokens.map((token) => token.char), 0);
  tokens.forEach((token, index) {
    if (isTashkeelArabicChar(token.char)) {
      return;
    }
    contextParams.setCurrentIndex(index);
    charContextParams.setCurrentIndex(index);
    var CONNECT = 0; // 2 bits 00 (10: can connect next) (01: can connect prev)
    if (willConnectPrev(charContextParams)) {
      CONNECT |= 1;
    }
    if (willConnectNext(charContextParams)) {
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

dynamic arabicWordStartCheck(contextParams) {
  var char = contextParams.current;
  var prevChar = contextParams.get(-1);
  return
      // ? arabic first char
      (prevChar == null && isArabicChar(char)) ||
          // ? arabic char preceded with a non arabic char
          (!isArabicChar(prevChar) && isArabicChar(char));
}

dynamic arabicWordEndCheck(contextParams) {
  // TODO: check get(1)
  var nextChar = contextParams.get(1);
  return
      // ? last arabic char
      (nextChar == null) ||
          // ? next char is not arabic
          (!isArabicChar(nextChar));
}

class ArabicWordCheck {
  get startCheck => arabicWordStartCheck;

  get endCheck => arabicWordEndCheck;
}

dynamic arabicSentenceStartCheck(contextParams) {
  var char = contextParams.current;
  var prevChar = contextParams.get(-1);
  return
      // ? an arabic char preceded with a non arabic char
      (isArabicChar(char) || isTashkeelArabicChar(char)) &&
          !isArabicChar(prevChar);
}

dynamic arabicSentenceEndCheck(contextParams) {
  var nextChar = contextParams.get(1);

  if (nextChar == null) {
    return true;
  } else if (!isArabicChar(nextChar) && !isTashkeelArabicChar(nextChar)) {
    var nextIsWhitespace = isWhiteSpace(nextChar);
    if (!nextIsWhitespace) {
      return true;
    }
    if (nextIsWhitespace) {
      var arabicCharAhead = false;
      // TODO: checl first error
      arabicCharAhead = (contextParams.lookahead
          .firstWhere((c) => isArabicChar(c) ?? isTashkeelArabicChar(c)));
      if (arabicCharAhead == null) {
        return true;
      }
    }
  } else {
    return false;
  }
}

class ArabicSentenceCheck {
  get startCheck => arabicWordStartCheck;

  get endCheck => arabicWordEndCheck;
}
