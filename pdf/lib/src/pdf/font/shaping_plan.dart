import '../../../pdf.dart';

/**
 * ShapingPlans are used by the OpenType shapers to store which
 * features should by applied, and in what order to apply them.
 * The features are applied in groups called stages. A feature
 * can be applied globally to all glyphs, or locally to only
 * specific glyphs.
 *
 * @private
 */
class ShapingPlan {
  ShapingPlan(this.font, this.direction) {}
  final TtfParser font;
  String direction = 'ltr';
  Map<String, dynamic> globalFeatures = {};
  Map<String, dynamic> allFeatures = {};
  List<dynamic> stages = [];

  /**
   * Adds the given features to the last stage.
   * Ignores features that have already been applied.
   */
  _addFeatures(List<String> features, global) {
    int stageIndex = this.stages.length - 1;
    var stage = this.stages[stageIndex];
    for (var feature in features) {
      if (this.allFeatures[feature] == null) {
        stage.push(feature);
        this.allFeatures[feature] = stageIndex;

        if (global) {
          this.globalFeatures[feature] = true;
        }
      }
    }
  }

  add(dynamic arg, [bool global = true]) {
    if (this.stages.length == 0) {
      this.stages.add([]);
    }

    if (arg is String) {
      arg = [arg];
    }

    if (arg is List<String>) {
      this._addFeatures(arg, global);
    } else if (arg is Map) {
      this._addFeatures(arg['global'] ?? [], true);
      this._addFeatures(arg['local'] ?? [], false);
    } else {
      throw 'Unsupported argument to ShapingPlan#add';
    }
  }

  /**
   * Add a new stage
   */
  addStage(arg, global) {
    if (arg is Function) {
      this.stages.add(arg);
      this.stages.add([]);
    } else {
      this.stages.add([]);
      this.add(arg, global);
    }
  }

  setFeatureOverrides(dynamic features) {
    if (features is List) {
      this.add(features);
    } else if (features is Map) {
      for (var tag in features.keys) {
        if (features[tag]) {
          this.add(tag);
        } else if (this.allFeatures[tag] != null) {
          var stage = this.stages[this.allFeatures[tag]];
          stage.splice(stage.indexOf(tag), 1);
          this.allFeatures.remove(tag);
          this.globalFeatures.remove(tag);
        }
      }
    }
  }

  /**
   * Assigns the global features to the given glyphs
   */
  assignGlobalFeatures(List<dynamic> glyphs) {
    for (var glyph in glyphs) {
      for (var feature in this.globalFeatures.keys) {
        glyph.features[feature] = true;
      }
    }
  }

  /**
   * Executes the planned stages using the given OTProcessor
   */
  process(processor, glyphs, positions) {
    for (var stage in this.stages) {
      if (stage is Function) {
        if (!positions) {
          stage(this.font, glyphs, this);
        }
      } else if (stage.length > 0) {
        processor.applyFeatures(stage, glyphs, positions);
      }
    }
  }
}
