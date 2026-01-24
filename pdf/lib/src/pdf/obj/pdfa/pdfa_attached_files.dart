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

class PdfaAttachedFile {
  final String name;
  final String data;
  final String AFRelationship;
  final String subType;

  PdfaAttachedFile({
    required this.name,
    required this.data,
    this.subType = '/text/xml',
    this.AFRelationship = '/Alternative',
  });
}

class PdfaAttachedFiles {
  PdfaAttachedFiles(
    PdfDocument pdfDocument,
    List<PdfaAttachedFile> files, 
  ) {
    for (var file in files) {
      _files.add(
        _AttachedFileSpec(
          pdfDocument,
          _AttachedFile(
            pdfDocument,
            file.name,
            file.data,
            file.subType,
          ),
          file.AFRelationship,
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
      _files.map((spec) => _PdfRaw(spec._file.fileName, spec)).toList(),
    );
  }
}

class _AttachedFileSpec extends PdfObject<PdfDict> {
  _AttachedFileSpec(
    PdfDocument pdfDocument,
    this._file,
    this.relationship,
  ) : super(
          pdfDocument,
          params: PdfDict(),
        );
  final _AttachedFile _file;
  final String relationship;

  @override
  void prepare() {
    super.prepare();

    params['/Type'] = const PdfName('/Filespec');
    params['/F'] = PdfString(Uint8List.fromList(_file.fileName.codeUnits));
    params['/UF'] = PdfString(Uint8List.fromList(_file.fileName.codeUnits));
    params['/EF'] = PdfDict({'/F': _file.ref()});
    
    params['/AFRelationship'] = PdfName(relationship);
  }
}

class _AttachedFile extends PdfObject<PdfDictStream> {
  _AttachedFile(
    PdfDocument pdfDocument,
    this.fileName,
    this.content,
    this.subType,
  ) : super(
          pdfDocument,
          params: PdfDictStream(
            compress: false,
            encrypt: false,
          ),
        );

  final String fileName;
  final String content;
  final String subType;

  @override
  void prepare() {
    super.prepare();

    final modDate = PdfaDateFormat().format(dt: DateTime.now());
    params['/Type'] = const PdfName('/EmbeddedFile');
    
    params['/Subtype'] = PdfName(subType);
    
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
  const _PdfRaw(this.name, this.spec);

  final String name;
  final _AttachedFileSpec spec;

  @override
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    s.putString('($name) ${spec.ref()}');
  }
}
