import 'gsub_parser.dart';
import 'ot_processor.dart';

class GSUBProcessor extends OTProcessor {
  GSUBProcessor(super.font, super.table);

  @override
  bool applyLookup(int lookupType, SubTable table) {
    dynamic t = table.substituteTable;

    if (lookupType == 4) {
      int index = this.coverageIndex(t.coverage);
      if (index == -1) {
        return false;
      }

      for (var ligature in t.ligatureSets[index]) {
        bool matched = this.sequenceMatchIndices(1, ligature.components);
        if (!matched) {
          continue;
        }
      }
    }
    return false;
  }
}
