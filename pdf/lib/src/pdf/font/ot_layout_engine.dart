import 'glyph_info.dart';
import 'gpos_processor.dart';
import 'gsub_parser.dart';
import 'gsub_processor.dart';
import 'layout/glyph_run.dart';
import 'shapers/shapers.dart';
import 'shaping_plan.dart';
import 'ttf_parser.dart';

class OTLayoutEngine {
  OTLayoutEngine(this.font) {
    if (this.font.gsub != null) {
      gsubProcessor = GSUBProcessor(this.font, this.font.gsub!);
    }

    if (this.font.gpos != null) {
      gposProcessor = GPOSProcessor(this.font, this.font.gpos!);
    }
  }
  final TtfParser font;
  GSUBProcessor? gsubProcessor;
  GPOSProcessor? gposProcessor;
  dynamic shaper;
  ShapingPlan? plan;
  List<GlyphInfo> glyphInfos = [];

  setup(GlyphRun glyphRun) {
    // Map glyphs to GlyphInfo objects so data can be passed between
    // GSUB and GPOS without mutating the real (shared) Glyph objects.
    this.glyphInfos = glyphRun.glyphs
        .map((glyph) => GlyphInfo(this.font, glyph.id, [...glyph.codePoints]))
        .toList();

    // Select a script based on what is available in GSUB/GPOS.
    String? script;
    if (this.gposProcessor != null) {
      script = this
          .gposProcessor!
          .selectScript(glyphRun.script, glyphRun.language, glyphRun.direction);
    }

    if (this.gsubProcessor != null) {
      script = this
          .gsubProcessor!
          .selectScript(glyphRun.script, glyphRun.language, glyphRun.direction);
    }

    // Choose a shaper based on the script, and setup a shaping plan.
    // This determines which features to apply to which glyphs.
    this.shaper = chooseShaper(script);
    this.plan = ShapingPlan(this.font, script, glyphRun.direction);
    this.shaper.plan(this.plan, this.glyphInfos, glyphRun.features);

    // Assign chosen features to output glyph run
    for (var key in this.plan!.allFeatures.keys) {
      glyphRun.features[key] = true;
    }
  }

  substitute(GlyphRun glyphRun) {
    if (this.gsubProcessor != null) {
      this.plan!.process(this.gsubProcessor, this.glyphInfos);

      // Map glyph infos back to normal Glyph objects
      //glyphRun.glyphs = this.glyphInfos.map(glyphInfo => this.font.getGlyph(glyphInfo.id, glyphInfo.codePoints)).toList();
    }
  }

  Map<String, FeatureTable>? position(GlyphRun glyphRun) {
    if (this.shaper.zeroMarkWidths == 'BEFORE_GPOS') {
      this.zeroMarkAdvances(glyphRun.positions);
    }

    if (this.gposProcessor != null) {
      this
          .plan!
          .process(this.gposProcessor, this.glyphInfos, glyphRun.positions);
    }

    if (this.shaper.zeroMarkWidths == 'AFTER_GPOS') {
      this.zeroMarkAdvances(glyphRun.positions);
    }

    // Reverse the glyphs and positions if the script is right-to-left
    if (glyphRun.direction == 'rtl') {
      glyphRun.glyphs.reversed.toList();
      glyphRun.positions.reversed.toList();
    }

    if (this.gposProcessor != null) {
      return this.gposProcessor!.features;
    }
    return null;
  }

  zeroMarkAdvances(positions) {
    for (int i = 0; i < this.glyphInfos.length; i++) {
      if (this.glyphInfos[i].isMark) {
        positions[i].xAdvance = 0;
        positions[i].yAdvance = 0;
      }
    }
  }

  cleanup() {
    this.glyphInfos = [];
    this.plan = null;
    this.shaper = null;
  }

  List<String> getAvailableFeatures(script, language) {
    List<String> features = [];

    if (this.gsubProcessor != null) {
      this.gsubProcessor!.selectScript(script, language);
      features.addAll([...this.gsubProcessor!.features.keys]);
    }

    if (this.gposProcessor != null) {
      this.gposProcessor!.selectScript(script, language);
      features.addAll([...this.gposProcessor!.features.keys]);
    }

    return features;
  }
}
