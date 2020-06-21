part of pdf;

class Tokenizer {
  List<Token> tokens = [];
  Map<String, dynamic> registeredContexts = {};
  List<ContextChecker> contextCheckers = [];
  dynamic events = {};
  List<dynamic> registeredModifiers = [];

  Tokenizer([dynamic events]) {
    initializeCoreEvents(events);
  }

  /**
   * Initialize a core events and auto subscribe required event handlers
   * @param {any} events an object that enlists core events handlers
   */
  initializeCoreEvents(Map<String, dynamic> events) {
    var coreEvents = [
      'start',
      'end',
      'next',
      'newToken',
      'contextStart',
      'contextEnd',
      'insertToken',
      'removeToken',
      'removeRange',
      'replaceToken',
      'replaceRange',
      'composeRUD',
      'updateContextsRanges'
    ];

    coreEvents.forEach((eventId) {
      this.events[eventId] = Event(eventId);
    });

    if (events != null) {
      coreEvents.forEach((eventId) {
        var event = events[eventId];
        if (event is Function) {
          this.events[eventId].subscribe(event);
        }
      });
    }

    var requiresContextUpdate = [
      'insertToken',
      'removeToken',
      'removeRange',
      'replaceToken',
      'replaceRange',
      'composeRUD'
    ];
    requiresContextUpdate.forEach((eventId) {
      this.events[eventId].subscribe(this.updateContextsRanges);
    });
  }

  /**
   * Converts a context range into a string value
   * @param {contextRange} range a context range
   */
  dynamic rangeToText(dynamic range) {
    if (range is ContextRange) {
      return (this.getRangeTokens(range).map((token) => token.char).join(''));
    }
  }

  /**
   * Converts all tokens into a string
   */
  dynamic getText() {
    return this.tokens.map((token) => token.char).join('');
  }

  /**
   * Get a context by name
   * @param {string} contextName context name to get
   */
  dynamic getContext(String contextName) {
    var context = this.registeredContexts[contextName];
    return context ?? null;
  }

  /**
   * Subscribes a new event handler to an event
   * @param {string} eventName event name to subscribe to
   * @param {function} eventHandler a function to be invoked on event
   */
  dynamic on(String eventName, dynamic eventHandler) {
    var event = this.events[eventName];
    if (event != null) {
      return event.subscribe(eventHandler);
    } else {
      return null;
    }
  }

  /**
   * Dispatches an event
   * @param {string} eventName event name
   * @param {any} args event handler arguments
   */
  dynamic dispatch(String eventName, [dynamic args]) {
    var event = this.events[eventName];
    if (event is Event) {
      event.subscribers.forEach((subscriber) {
        Function.apply(subscriber, args ?? []);
      });
    }
  }

  /**
   * Register a new context checker
   * @param {string} contextName a unique context name
   * @param {function} contextStartCheck a predicate function that returns true on context start
   * @param {function} contextEndCheck  a predicate function that returns true on context end
   * TODO: call tokenize on registration to update context ranges with the new context.
   */
  dynamic registerContextChecker(
    contextName,
    contextStartCheck,
    contextEndCheck,
  ) {
    if (this.getContext(contextName) != null) {
      return;
    }
    if (!(contextStartCheck is Function)) {
      return;
    }
    if (!(contextEndCheck is Function)) {
      return;
    }
    var contextCheckers =
        ContextChecker(contextName, contextStartCheck, contextEndCheck);
    this.registeredContexts[contextName] = contextCheckers;
    this.contextCheckers.add(contextCheckers);
    return contextCheckers;
  }

  /**
   * Gets a context range tokens
   * @param {contextRange} range a context range
   */
  dynamic getRangeTokens(ContextRange range) {
    var endIndex = range.startIndex + range.endOffset;
    return [...this.tokens.sublist(range.startIndex, endIndex)];
  }

  /**
   * Gets the ranges of a context
   * @param {string} contextName context name
   */
  dynamic getContextRanges(String contextName) {
    var context = this.getContext(contextName);
    if (context != null) {
      return context.ranges;
    } else {
      return;
    }
  }

  /**
   * Resets context ranges to run context update
   */
  dynamic resetContextsRanges() {
    var registeredContexts = this.registeredContexts;
    registeredContexts.keys.forEach((contextName) {
      if (registeredContexts.containsKey(contextName)) {
        var context = registeredContexts[contextName];
        context.ranges = [];
      }
    });
  }

  /**
   * Updates context ranges
   */
  dynamic updateContextsRanges() {
    this.resetContextsRanges();
    var chars = this.tokens.map((token) => token.char).toList();
    for (int i = 0; i < chars.length; i++) {
      var contextParams = ContextParams(chars, i);
      this.runContextCheck(contextParams);
    }
    this.dispatch('updateContextsRanges', [this.registeredContexts]);
  }

  /**
   * Sets the end offset of an open range
   * @param {number} offset range end offset
   * @param {string} contextName context name
   */
  dynamic setEndOffset(offset, contextName) {
    int startIndex = this.getContext(contextName).openRange.startIndex;
    var range = ContextRange(startIndex, offset, contextName);
    var ranges = this.getContext(contextName).ranges;
    range.rangeId =
        "$contextName.${ranges.length}"; // TODO: Check range ID USage
    ranges.add(range);
    this.getContext(contextName).openRange = null;
    return range;
  }

  /**
   * Runs a context check on the current context
   * @param {contextParams} contextParams current context params
   */
  dynamic runContextCheck(contextParams) {
    int index = contextParams.index;
    this.contextCheckers.forEach((dynamic contextChecker) {
      String contextName = contextChecker.contextName;
      var openRange = this.getContext(contextName).openRange;
      if (openRange == null && contextChecker.checkStart(contextParams)) {
        openRange = ContextRange(index, null, contextName);
        this.getContext(contextName).openRange = openRange;
        this.dispatch('contextStart', [contextName, index]);
      }
      if (openRange != null && contextChecker.checkEnd(contextParams)) {
        int offset = (index - openRange.startIndex) + 1;
        var range = this.setEndOffset(offset, contextName);
        this.dispatch('contextEnd', [contextName, range]);
      }
    });
  }

  /**
   * Converts a text into a list of tokens
   * @param {string} text a text to tokenize
   */
  dynamic tokenize(String text) {
    this.tokens = [];
    this.resetContextsRanges();
    var chars = text.split("").toList();
    this.dispatch('start');
    for (int i = 0; i < chars.length; i++) {
      var char = chars[i];
      var contextParams = ContextParams(chars, i);
      this.dispatch('next', [contextParams]);
      this.runContextCheck(contextParams);
      var token = Token(char);
      this.tokens.add(token);
      this.dispatch('newToken', [token, contextParams]);
    }
    this.dispatch('end', [this.tokens]);
    return this.tokens;
  }

  /**
   * Checks if an index exists in the tokens list.
   * @param {number} index token index
   */
  dynamic inboundIndex(index) {
    return index >= 0 && index < this.tokens.length;
  }

  /**
   * Compose and apply a list of operations (replace, update, delete)
   * @param {array} RUDs replace, update and delete operations
   * TODO: Perf. Optimization (lengthBefore === lengthAfter ? dispatch once)
   */
  dynamic composeRUD(RUDs) {
    var silent = true;
    // TODO: Check login and refactor
//    var state = RUDs.map((dynamic RUD) =>
//    (
//        this[RUD[0]].apply(this, RUD.slice(1).concat(silent))
//    )).toList();

//    var hasFAILObject = (obj) =>
//    (
//        obj is Object
//    );
//    if (state.every(hasFAILObject)) {
//      return null;
//    }
    //this.dispatch('composeRUD', [state.filter( (op) => !hasFAILObject(op))]);
  }

  /**
   * Replace a range of tokens with a list of tokens
   * @param {number} startIndex range start index
   * @param {number} offset range offset
   * @param {token} tokens a list of tokens to replace
   * @param {boolean} silent dispatch events and update context ranges
   */
  dynamic replaceRange(int startIndex, offset, tokens, [bool silent = false]) {
    offset = offset != null ? offset : this.tokens.length;
    var isTokenType = tokens.every((token) => token is Token);
    if (!(startIndex.isNaN) && this.inboundIndex(startIndex) && isTokenType) {
      // TODO: Check logic
//      var replaced = this.tokens.splice.apply(
//          this.tokens, [startIndex, offset].add(tokens)
//      );
      if (!silent) this.dispatch('replaceToken', [startIndex, offset, tokens]);
      return [tokens]; //[replaced, tokens];
    } else {
      return null;
    }
  }

  /**
   * Replace a token with another token
   * @param {number} index token index
   * @param {token} token a token to replace
   * @param {boolean} silent dispatch events and update context ranges
   */
  dynamic replaceToken(int index, token, silent) {
    if (!(index.isNaN) && this.inboundIndex(index) && token is Token) {
      this.tokens.replaceRange(index, index + 1, [token]);
      var replaced = [...this.tokens];
      if (!silent) {
        this.dispatch('replaceToken', [index, token]);
      }
      return [replaced[0], token];
    } else {
      return null;
    }
  }

  /**
   * Removes a range of tokens
   * @param {number} startIndex range start index
   * @param {number} offset range offset
   * @param {boolean} silent dispatch events and update context ranges
   */
  dynamic removeRange(startIndex, int offset, silent) {
    offset = !(offset.isNaN) ? offset : this.tokens.length;
    // TODO: check rmeove range behviour
    this.tokens.removeRange(
        startIndex, startIndex + offset + 1); // exclusiev aahe mhnun 1add kela
    var tokens = [...this.tokens];
    if (!silent) this.dispatch('removeRange', [tokens, startIndex, offset]);
    return tokens;
  }

  /**
   * Remove a token at a certain index
   * @param {number} index token index
   * @param {boolean} silent dispatch events and update context ranges
   */
  dynamic removeToken(int index, silent) {
    if (!(index.isNaN) && this.inboundIndex(index)) {
      var token = this.tokens.removeAt(index);
      if (!silent) this.dispatch('removeToken', [token, index]);
      return token;
    } else {
      return null;
    }
  }

  /**
   * Insert a list of tokens at a certain index
   * @param {array} tokens a list of tokens to insert
   * @param {number} index insert the list of tokens at index
   * @param {boolean} silent dispatch events and update context ranges
   */
  dynamic insertToken(List<Token> tokens, index, silent) {
    var tokenType = tokens.every((token) => token is Token);
    if (tokenType) {
      this.tokens.insertAll(index, tokens);
      if (!silent) this.dispatch('insertToken', [tokens, index]);
      return tokens;
    } else {
      return null;
    }
  }

  /**
   * A state modifier that is called on 'newToken' event
   * @param {string} modifierId state modifier id
   * @param {function} condition a predicate function that returns true or false
   * @param {function} modifier a function to update token state
   */
  dynamic registerModifier(
      String modifierId, Function condition, Function modifier) {
    this.events["newToken"].subscribe((token, contextParams) {
      var conditionParams = [token, contextParams];
      var canApplyModifier = (condition == null ||
          Function.apply(condition, conditionParams) == true);
      var modifierParams = [token, contextParams];
      if (canApplyModifier) {
        var newStateValue = Function.apply(modifier, modifierParams);
        token.setState(modifierId, newStateValue);
      }
    });
    this.registeredModifiers.add(modifierId);
  }
}

class Token {
  final String char;
  var state = {};
  var activeState = null;

  Token(this.char);

  /**
   * Sets the state of a token, usually called by a state modifier.
   * @param {string} key state item key
   * @param {any} value state item value
   */
  dynamic setState(key, value) {
    this.state[key] = value;
    this.activeState = {"key": key, "value": this.state[key]};
    return this.activeState;
  }

  dynamic getState(String stateId) {
    return this.state[stateId] ?? null;
  }
}

/**
 * Create a new context range
 * @param {number} startIndex range start index
 * @param {number} endOffset range end index offset
 * @param {string} contextName owner context name
 */
class ContextRange {
  final String contextName;
  final int startIndex;
  final int endOffset;
  String rangeId;

  ContextRange(this.startIndex, this.endOffset, this.contextName);
}

/**
 * Check context start and end
 * @param {string} contextName a unique context name
 * @param {function} checkStart a predicate function the indicates a context's start
 * @param {function} checkEnd a predicate function the indicates a context's end
 */
class ContextChecker {
  final String contextName;
  final Function checkStart;
  final Function checkEnd;

  var openRange = null;
  var ranges = [];

  ContextChecker(this.contextName, this.checkStart, this.checkEnd);
}

/**
 * @typedef ContextParams
 * @type Object
 * @property {array} context context items
 * @property {number} currentIndex current item index
 */

/**
 * Create a context params
 * @param {array} context a list of items
 * @param {number} currentIndex current item index
 */
class ContextParams {
  final List<dynamic> context;
  int index;
  var length;
  var current;
  List<dynamic> backtrack;
  List<dynamic> lookahead;

  ContextParams(this.context, this.index) {
    this.length = context.length;
    this.current = context[index];
    this.backtrack = context.sublist(0, index);
    this.lookahead = context.sublist(index + 1);
  }

  /**
   * Sets context params current value index
   * @param {number} index context params current value index
   */
  dynamic setCurrentIndex(int index) {
    this.index = index;
    this.current = this.context[index];
    this.backtrack = this.context.sublist(0, index);
    this.lookahead = this.context.sublist(index + 1);
  }

  /**
   * Get an item at an offset from the current value
   * example (current value is 3):
   *  1    2   [3]   4    5   |   items values
   * -2   -1    0    1    2   |   offset values
   * @param {number} offset an offset from current value index
   */
  dynamic get(int offset) {
    if (offset == 0) {
      return this.current;
    } else if (offset < 0 && offset.abs() <= this.backtrack.length) {
      return this.backtrack[this.backtrack.length - 1];
    } else if (offset > 0 && offset <= this.lookahead.length) {
      return this.lookahead[offset - 1];
    } else {
      return null;
    }
  }
}

/**
 * Create an event instance
 * @param {string} eventId event unique id
 */
class Event {
  final String eventId;
  dynamic subscribers = [];

  Event(this.eventId);

  /**
   * Subscribe a handler to an event
   * @param {function} eventHandler an event handler function
   */
  dynamic subscribe(eventHandler) {
    if (eventHandler is Function) {
      // TODO check -1
      return this.subscribers.add(eventHandler);
    } else {
      return null;
    }
  }

  /**
   * Unsubscribe an event handler
   * @param {string} subsId subscription id
   */
  void unsubscribe(subsId) {
    this.subscribers.removeWhere((subId) => subId == subsId);
  }
}
