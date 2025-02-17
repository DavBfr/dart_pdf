import 'dart:convert';
import 'dart:typed_data';

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
import 'pdfa_date_format.dart';

class PdfaAttachedFiles {
  PdfaAttachedFiles(
    PdfDocument pdfDocument,
    Map<String, String> files,
  ) {
    for (var entry in files.entries) {
      _files.add(
        _AttachedFileSpec(
          pdfDocument,
          _AttachedFile(
            pdfDocument,
            entry.key,
            entry.value,
          ),
        ),
      );
    }
    _names = _AttachedFileNames(
      pdfDocument,
      _files,
    );
    pdfDocument.pdfNames;
    pdfDocument.catalog.attached = this;
  }

  final List<_AttachedFileSpec> _files = [];

  late final _AttachedFileNames _names;

  bool get isNotEmpty => _files.isNotEmpty;

  PdfDict catalogNames() {
    return PdfDict({
      '/EmbeddedFiles': _names.ref(),
    });
  }

  PdfArray catalogAF() {
    final tmp = <PdfIndirect>[];
    for (var spec in _files) {
      tmp.add(spec.ref());
    }
    return PdfArray(tmp);
  }
}

class _AttachedFileNames extends PdfObject<PdfDict> {
  _AttachedFileNames(
    PdfDocument pdfDocument,
    this._files,
  ) : super(
          pdfDocument,
          params: PdfDict(),
        );
  final List<_AttachedFileSpec> _files;

  @override
  void prepare() {
    super.prepare();
    params['/Names'] = PdfArray(
      [
        _PdfRaw(0, _files.first),
      ],
    );
  }
}

class _AttachedFileSpec extends PdfObject<PdfDict> {
  _AttachedFileSpec(
    PdfDocument pdfDocument,
    this._file,
  ) : super(
          pdfDocument,
          params: PdfDict(),
        );
  final _AttachedFile _file;

  @override
  void prepare() {
    super.prepare();

    params['/Type'] = const PdfName('/Filespec');
    params['/F'] = PdfString(
      Uint8List.fromList(_file.fileName.codeUnits),
    );
    params['/UF'] = PdfString(
      Uint8List.fromList(_file.fileName.codeUnits),
    );
    params['/EF'] = PdfDict({
      '/F': _file.ref(),
    });
    params['/AFRelationship'] = const PdfName('/Unspecified');
  }
}

class _AttachedFile extends PdfObject<PdfDictStream> {
  _AttachedFile(
    PdfDocument pdfDocument,
    this.fileName,
    this.content,
  ) : super(
          pdfDocument,
          params: PdfDictStream(
            compress: false,
            encrypt: false,
          ),
        );

  final String fileName;
  final String content;

  @override
  void prepare() {
    super.prepare();

    final modDate = PdfaDateFormat().format(dt: DateTime.now());
    params['/Type'] = const PdfName('/EmbeddedFile');
    params['/Subtype'] = const PdfName('/application/octet-stream');
    params['/Params'] = PdfDict({
      '/Size': PdfNum(content.codeUnits.length),
      '/ModDate': PdfString(
        Uint8List.fromList('D:$modDate+00\'00\''.codeUnits),
      ),
    });

    params.data = Uint8List.fromList(utf8.encode(content));
  }
}

class _PdfRaw extends PdfDataType {
  const _PdfRaw(
    this.nr,
    this.spec,
  );

  final int nr;
  final _AttachedFileSpec spec;

  @override
  void output(
    PdfObjectBase o,
    PdfStream s, [
    int? indent,
  ]) {
    s.putString('(${nr.toString().padLeft(3, '0')}) ${spec.ref()}');
  }
}
