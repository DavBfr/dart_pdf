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
import '../../format/string.dart';
import '../object.dart';
import 'pdfa_date_format.dart';

class PdfaAttachedFile {
  PdfaAttachedFile({
    required this.name,
    required this.data,
    this.subType = '/text/xml',
    // ignore: non_constant_identifier_names
    @Deprecated('Use afRelationship instead') String? AFRelationship,
    String afRelationship = '/Alternative',
  }) : afRelationship = AFRelationship ?? afRelationship;

  final String name;
  final String data;
  final String afRelationship;
  final String subType;
}

class PdfaAttachedFiles {
  PdfaAttachedFiles(PdfDocument pdfDocument, List<PdfaAttachedFile> files) {
    for (var file in files) {
      _files.add(
        _AttachedFileSpec(
          pdfDocument,
          _AttachedFile(pdfDocument, file.name, file.data, file.subType),
          file.afRelationship,
        ),
      );
    }
    _names = _AttachedFileNames(pdfDocument, _files);
    pdfDocument.pdfNames;
    pdfDocument.catalog.attached = this;
  }

  final List<_AttachedFileSpec> _files = [];
  late final _AttachedFileNames _names;

  bool get isNotEmpty => _files.isNotEmpty;

  PdfDict catalogNames() {
    return PdfDict({'/EmbeddedFiles': _names.ref()});
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
  _AttachedFileNames(PdfDocument pdfDocument, this._files)
    : super(pdfDocument, params: PdfDict());
  final List<_AttachedFileSpec> _files;

  @override
  void prepare() {
    super.prepare();

    // A name tree's keys have to be in ascending order - ISO 32000-1 7.9.6 - or
    // a consumer's binary search can miss an entry. The keys were emitted in
    // caller order, and written by a private raw type that put '($name) ref'
    // straight into the stream: no escaping, so an unbalanced ')' or a backslash
    // corrupted the object; no Latin-1/UTF-16BE choice, so a non-Latin-1 name was
    // truncated a code unit at a time; and no encrypt callback either.
    //
    // Sorted on a copy: _files is shared with the catalog's /AF array, which has
    // to keep the caller's order.
    final sorted = _files.toList()
      ..sort((a, b) => a._file.fileName.compareTo(b._file.fileName));

    params['/Names'] = PdfArray(<PdfDataType>[
      for (final spec in sorted) ...<PdfDataType>[
        PdfString.fromString(spec._file.fileName),
        spec.ref(),
      ],
    ]);
  }
}

class _AttachedFileSpec extends PdfObject<PdfDict> {
  _AttachedFileSpec(PdfDocument pdfDocument, this._file, this.relationship)
    : super(pdfDocument, params: PdfDict());
  final _AttachedFile _file;
  final String relationship;

  @override
  void prepare() {
    super.prepare();

    params['/Type'] = const PdfName('/Filespec');
    // fromString, not the raw code units: a code unit above 0xFF was truncated to
    // one byte, so a non-Latin-1 file name was mangled.
    params['/F'] = PdfString.fromString(_file.fileName);
    params['/UF'] = PdfString.fromString(_file.fileName);
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
        params: PdfDictStream(compress: false, encrypt: false),
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

    // ISO 32000-1 Table 46: /Size is the uncompressed size in bytes. It was the
    // UTF-16 code-unit count while the payload is written as UTF-8, so the two
    // agreed only for ASCII - a Factur-X attachment with accents declared 99 for
    // a 106-byte stream, and a consumer that trusts /Size truncated the XML.
    // Encoded once, so the dictionary and the stream cannot drift.
    final data = Uint8List.fromList(utf8.encode(content));

    params['/Params'] = PdfDict({
      '/Size': PdfNum(data.length),
      '/ModDate': PdfString(
        Uint8List.fromList('D:$modDate+00\'00\''.codeUnits),
      ),
    });

    params.data = data;
  }
}
