part of pdf;

class SupportedScripts {
  static String latinWord = "latinWord";
  static String arabicWord = "arabicWord";
  static String arabicSentence = "arabicSentence";
  static String devnagriWord = "dev2Word";
  static String devnagriSentense = "dev2Sentence";
}

class Bidi {
  String baseDir;
  var featuresTags = Map<String, dynamic>();
  var tokenizer = Tokenizer();
  String text;
  FeatureQuery query;

  /**
   * Sets Bidi text
   * @param {string} text a text input
   */
  dynamic setText(String text) {
    this.text = text;
  }

  /**
   * Store essential context checks:
   * arabic word check for applying gsub features
   * arabic sentence check for adjusting arabic layout
   */
  get contextChecks => {
        "${SupportedScripts.latinWord}Check": LatinWordCheck(),
        "${SupportedScripts.arabicWord}Check": ArabicWordCheck(),
        "${SupportedScripts.arabicSentence}Check": ArabicSentenceCheck(),
        "${SupportedScripts.devnagriWord}Check": DevnagariWordCheck(),
      };

  /**
   * Register arabic word check
   */
  dynamic registerContextChecker(checkId) {
    var check = this.contextChecks["${checkId}Check"];
    return this
        .tokenizer
        .registerContextChecker(checkId, check.startCheck, check.endCheck);
  }

  /**
   * Perform pre tokenization procedure then
   * tokenize text input
   */
  dynamic tokenizeText() {
    registerContextChecker('${SupportedScripts.latinWord}');
    registerContextChecker('${SupportedScripts.arabicWord}');
    registerContextChecker('${SupportedScripts.arabicSentence}');
    registerContextChecker('${SupportedScripts.devnagriWord}');
    return this.tokenizer.tokenize(this.text);
  }

  /**
   * Reverse arabic sentence layout
   * TODO: check base dir before applying adjustments - priority low
   */
  dynamic reverseArabicSentences() {
    var ranges =
        this.tokenizer.getContextRanges(SupportedScripts.arabicSentence);
    ranges.forEach((range) {
      var rangeTokens = this.tokenizer.getRangeTokens(range);
      this.tokenizer.replaceRange(
          range.startIndex, range.endOffset, rangeTokens.reverse());
    });
  }

  /**
   * Register supported features tags
   * @param {script} script script tag
   * @param {Array} tags features tags list
   */
  dynamic registerFeatures(String script, List<String> tags) {
    var supportedTags = tags
        .where((tag) =>
            this.query.supports(FeatureQuery(this.query.font, script, tag)))
        .toList();

    if (!this.featuresTags.containsKey(script)) {
      this.featuresTags[script] = supportedTags;
    } else {
      this.featuresTags[script] =
          this.featuresTags[script].concat(supportedTags);
    }
  }

  /**
   * Apply GSUB features
   * @param {Array} tagsList a list of features tags
   * @param {string} script a script tag
   * @param {Font} font opentype font instance
   */
  dynamic applyFeatures(TtfParser font, List<dynamic> features) {
    if (font == null) {
      throw Exception('No valid font was provided to apply features');
    }

    if (this.query == null) {
      this.query = new FeatureQuery(font);
    }
    for (int f = 0; f < features.length; f++) {
      var feature = features[f];
      var query = new FeatureQuery(font)..script = feature["script"];
      if (!this.query.supports(query)) {
        continue;
      }
      this.registerFeatures(feature["script"], feature["tags"]);
    }
  }

  /**
   * Register a state modifier
   * @param {string} modifierId state modifier id
   * @param {function} condition a predicate function that returns true or false
   * @param {function} modifier a modifier function to set token state
   */
  dynamic registerModifier(modifierId, condition, modifier) {
    this.tokenizer.registerModifier(modifierId, condition, modifier);
  }

  /**
   * Check if 'glyphIndex' is registered
   */
  dynamic checkGlyphIndexStatus() {
    if (this.tokenizer.registeredModifiers.indexOf('glyphIndex') == -1) {
      throw Exception('glyphIndex modifier is required to apply ' +
          'arabic presentation features.');
    }
  }

  /**
   * Apply arabic presentation forms features
   */
  dynamic applyArabicPresentationForms() {
    const script = 'arab';
    if (!this.featuresTags.containsKey(script)) {
      return;
    }
    checkGlyphIndexStatus();
    var ranges = this.tokenizer.getContextRanges(SupportedScripts.arabicWord);
    ranges.forEach((range) {
      arabicPresentationForms(range, this);
    });
  }

  /**
   * Apply required arabic ligatures
   */
  dynamic applyArabicRequireLigatures() {
    const script = 'arab';
    if (!this.featuresTags.containsKey(script)) {
      return;
    }
    var tags = this.featuresTags[script];
    if (tags.indexOf('rlig') == -1) return;
    checkGlyphIndexStatus();
    var ranges = this.tokenizer.getContextRanges(SupportedScripts.arabicWord);
    ranges.forEach((range) {
      arabicRequiredLigatures(range, this);
    });
  }

  /**
   * Apply required arabic ligatures
   */
  dynamic applyLatinLigatures() {
    const script = 'latn';
    if (!this.featuresTags.containsKey(script)) {
      return;
    }
    var tags = this.featuresTags[script];
    if (tags.indexOf('liga') == -1) return;
    checkGlyphIndexStatus();
    var ranges = this.tokenizer.getContextRanges(SupportedScripts.latinWord);
    ranges.forEach((range) {
      latinLigature(range, this);
    });
  }

  /**
   * Apply required arabic ligatures
   */
  dynamic applyDevnagariLigatures() {
    const script = 'dev2';
    if (!this.featuresTags.containsKey(script)) {
      return;
    }
    var tags = this.featuresTags[script];
//    if (tags.indexOf('frac') == -1) {
//      return;
//    }
    checkGlyphIndexStatus();
    var ranges = this.tokenizer.getContextRanges(SupportedScripts.devnagriWord);

    tags.forEach((tg) {
      ranges.forEach((range) {
        devnagriLigature(range, this, tg);
      });
    });
  }

  /**
   * Check if a context is registered
   * @param {string} contextId context id
   */
  dynamic checkContextReady(String contextId) {
    return this.tokenizer.getContext(contextId) != null;
  }

  /**
   * Apply features to registered contexts
   */
  dynamic applyFeaturesToContexts() {
    if (this.checkContextReady(SupportedScripts.arabicWord)) {
      applyArabicPresentationForms();
      applyArabicRequireLigatures();
    }
    if (this.checkContextReady(SupportedScripts.latinWord)) {
      applyLatinLigatures();
    }

    if (this.checkContextReady(SupportedScripts.devnagriWord)) {
      applyDevnagariLigatures();
    }
    if (this.checkContextReady(SupportedScripts.arabicSentence)) {
      reverseArabicSentences();
    }
  }

  /**
   * process text input
   * @param {string} text an input text
   */
  dynamic processText(text) {
    if (this.text != null || this.text != text) {
      this.setText(text);
      tokenizeText();
      this.applyFeaturesToContexts();
    }
  }

  /**
   * Process a string of text to identify and adjust
   * bidirectional text entities.
   * @param {string} text input text
   */
  dynamic getBidiText(text) {
    this.processText(text);
    return this.tokenizer.getText();
  }

  /**
   * Get the current state index of each token
   * @param {text} text an input text
   */
  dynamic getTextGlyphs(text) {
    this.processText(text);
    List<int> indexes = [];
    for (int i = 0; i < this.tokenizer.tokens.length; i++) {
      var token = this.tokenizer.tokens[i];
      if (token.state["deleted"] ?? false) {
        continue;
      }
      dynamic index = token.activeState["value"];
      indexes.add(index is List ? index[0] : index);
    }
    return indexes.where((element) => element != null).toList();
  }
}
