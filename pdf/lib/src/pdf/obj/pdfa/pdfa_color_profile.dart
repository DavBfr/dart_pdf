import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../document.dart';
import '../../format/array.dart';
import '../../format/base.dart';
import '../../format/dict.dart';
import '../../format/dict_stream.dart';
import '../../format/indirect.dart';
import '../../format/name.dart';
import '../../format/num.dart';
import '../../format/object_base.dart';
import '../../format/stream.dart';
import '../../format/string.dart';
import '../object.dart';

class PdfaColorProfile extends PdfObject<PdfDictStream> {
  PdfaColorProfile(
   PdfDocument pdfDocument,
   this.icc,
  ) : super(
    pdfDocument,
    params: PdfDictStream(
      compress: false,
      encrypt: false,
    ),
  ) {
    pdfDocument.catalog.colorProfile = this;
  }

  final Uint8List icc;

  @override
  void prepare() {
    super.prepare();
    params['/N'] = const PdfNum(3);
    params.data = icc;
  }

  PdfArray outputIntents() {
    return PdfArray<PdfDict>([
      PdfDict({
        '/Type': const PdfName('/OutputIntent'),
        '/S': const PdfName('/GTS_PDFA1'),
        '/OutputConditionIdentifier':
        PdfString(Uint8List.fromList('sRGB2014.icc'.codeUnits)),
        '/Info': PdfString(Uint8List.fromList('sRGB2014.icc'.codeUnits)),
        '/RegistryName':
        PdfString(Uint8List.fromList('http://www.color.org'.codeUnits)),
        '/DestOutputProfile': ref(),
      }),
    ]);
  }
}
