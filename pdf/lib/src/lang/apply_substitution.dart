part of pdf;

/**
 * Apply single substitution format 1
 * @param {Array} substitutions substitutions
 * @param {any} tokens a list of tokens
 * @param {number} index token index
 */
void singleSubstitutionFormat1x(action, tokens, index) {
  tokens[index].setState(action.tag, action.substitution);
}

/**
 * Apply single substitution format 2
 * @param {Array} substitutions substitutions
 * @param {any} tokens a list of tokens
 * @param {number} index token index
 */
void singleSubstitutionFormat2x(action, tokens, index) {
  tokens[index].setState(action.tag, action.substitution);
}

/**
 * Apply chaining context substitution format 3
 * @param {Array} substitutions substitutions
 * @param {any} tokens a list of tokens
 * @param {number} index token index
 */
void chainingSubstitutionFormat3x(action, tokens, index) {
  action.substitution.forEach((subst, offset) {
    Token token = tokens[index + offset];
    token.setState(action.tag, subst);
  });
}

/**
 * Apply ligature substitution format 1
 * @param {Array} substitutions substitutions
 * @param {any} tokens a list of tokens
 * @param {number} index token index
 */
void ligatureSubstitutionFormat1x(action, tokens, index) {
  Token token = tokens[index];
  token.setState(action.tag, action.substitution["ligGlyph"]);
  var compsCount = action.substitution["components"].length;
  for (int i = 0; i < compsCount; i++) {
    token = tokens[index + i + 1];
    token.setState('deleted', true);
  }
}

/**
 * Supported substitutions
 */
var SUBSTITUTIONS = {
  11: singleSubstitutionFormat1x,
  12: singleSubstitutionFormat2x,
  63: chainingSubstitutionFormat3x,
  41: ligatureSubstitutionFormat1x,
  71: singleSubstitutionFormat1x,
};

/**
 * Apply substitutions to a list of tokens
 * @param {Array} substitutions substitutions
 * @param {any} tokens a list of tokens
 * @param {number} index token index
 */
void applySubstitution(action, tokens, index) {
  if (action is SubstitutionAction && SUBSTITUTIONS[action.id] != null) {
    SUBSTITUTIONS[action.id](action, tokens, index);
  }
}
