import 'gsub_processor.dart';
import 'ttf_parser.dart';

class OTLayoutEngine {
  OTLayoutEngine(this.font) {
    if (this.font.gsub != null) {
      gsubProcessor = GSUBProcessor(this.font, this.font.gsub!);
    }
  }
  final TtfParser font;
  GSUBProcessor? gsubProcessor;

  setup() {}
}
