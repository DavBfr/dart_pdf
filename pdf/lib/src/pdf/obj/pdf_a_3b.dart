import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../document.dart';
import '../format/array.dart';
import '../format/base.dart';
import '../format/dict.dart';
import '../format/dict_stream.dart';
import '../format/indirect.dart';
import '../format/name.dart';
import '../format/num.dart';
import '../format/object_base.dart';
import '../format/stream.dart';
import '../format/string.dart';
import 'object.dart';

/// Here are some classes to help you creating PDF/A compliant PDFs
/// plus embedding Facturx invoices
///
/// Rules:
///
/// 1. Your PDF must only use embedded Fonts,
/// 2. For now you cannot use any Annotations in your PDF
/// 3. You must include a special Meta-XML, use below "PdfaRdf" and put the reuslting XML document into your documents metadata
/// 4. You muss include a Colorprofile, use the below "PdfaColorProfile" and embed the contents of "sRGB2014.icc"
/// 5. Optionally attach an InvoiceXML using "PdfaFacturxRdf" and "PdfaAttachedFiles"
///
/// Example:
///
/// pw.Document pdf = pw.Document(
///   ...
///   metadata: PdfaRdf(
///     ...
///     invoiceRdf: PdfaFacturxRdf().create()
///   ).create(),
/// );
/// ColorProfile(
///   pdf.document,
///   File('sRGB2014.icc').readAsBytesSync(),
/// );
/// AttachedFiles(
///   pdf.document,
///   {
///     'factur-x.xml': myInvoiceXmlDocument,
///   },
/// );
///
/// Validating:
///
/// https://demo.verapdf.org
/// https://avepdf.com/pdfa-validation
/// https://www.mustangproject.org
///

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

class PdfaRdf {
  PdfaRdf({
    this.title,
    this.author,
    this.creator,
    this.subject,
    this.keywords,
    this.producer,
    DateTime? creationDate,
    this.invoiceRdf = '',
  }) {
    this.creationDate = creationDate ?? DateTime.now();
  }

  final String? title;
  final String? author;
  final String? creator;
  final String? subject;
  final String? keywords;
  final String? producer;
  late final DateTime creationDate;
  final String invoiceRdf;

  XmlDocument? create() {
    var createDate = _DateFormat().format(dt: creationDate, asIso: true);
    final offset = creationDate.timeZoneOffset;
    final hours =
    offset.inHours > 0 ? offset.inHours : 1; // For fixing divide by 0
    if (!offset.isNegative) {
      createDate =
      "$createDate+${offset.inHours.toString().padLeft(2, '0')}:${(offset.inMinutes % (hours * 60)).toString().padLeft(2, '0')}";
    } else {
      createDate =
      "$createDate-${(-offset.inHours).toString().padLeft(2, '0')}:${(offset.inMinutes % (hours * 60)).toString().padLeft(2, '0')}";
    }

    return XmlDocument.parse('''
<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
    <pdf:Producer>$producer</pdf:Producer>
    <pdf:Keywords>$keywords</pdf:Keywords>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
    <xmp:CreateDate>$createDate</xmp:CreateDate>
    <xmp:CreatorTool>$creator</xmp:CreatorTool>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:creator><rdf:Seq><rdf:li>$author</rdf:li></rdf:Seq></dc:creator>
    <dc:title><rdf:Alt><rdf:li xml:lang="x-default">$title</rdf:li></rdf:Alt></dc:title>
    <dc:description><rdf:Alt><rdf:li xml:lang="x-default">$subject</rdf:li></rdf:Alt></dc:description>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
    <pdfaid:part>3</pdfaid:part>
    <pdfaid:conformance>B</pdfaid:conformance>
  </rdf:Description>
  
  $invoiceRdf
  
</rdf:RDF>
<?xpacket end="r"?>
''');
  }
}

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

    final modDate = _DateFormat().format(dt: DateTime.now());
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
  void output(PdfObjectBase o, PdfStream s, [int? indent]) {
    s.putString('(${nr.toString().padLeft(3, '0')}) ${spec.ref()}');
  }
}

class PdfaFacturxRdf {
  String create() {
    return '''
    
<rdf:Description xmlns:fx="urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#" rdf:about="">
  <fx:DocumentType>INVOICE</fx:DocumentType>
  <fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>
  <fx:Version>1.0</fx:Version>
  <fx:ConformanceLevel>BASIC</fx:ConformanceLevel>
</rdf:Description>
    
<rdf:Description xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"
  xmlns:pdfaField="http://www.aiim.org/pdfa/ns/field#"
  xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#"
  xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#"
  xmlns:pdfaType="http://www.aiim.org/pdfa/ns/type#"
  rdf:about=""
>
  <pdfaExtension:schemas>
    <rdf:Bag>
      <rdf:li rdf:parseType="Resource">
        <pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>
        <pdfaSchema:namespaceURI>urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#</pdfaSchema:namespaceURI>
        <pdfaSchema:prefix>fx</pdfaSchema:prefix>
        <pdfaSchema:property>
          <rdf:Seq>
            <rdf:li rdf:parseType="Resource">
              <pdfaProperty:name>DocumentFileName</pdfaProperty:name>
              <pdfaProperty:valueType>Text</pdfaProperty:valueType>
              <pdfaProperty:category>external</pdfaProperty:category>
              <pdfaProperty:description>name of the embedded XML invoice file</pdfaProperty:description>
            </rdf:li>
              <rdf:li rdf:parseType="Resource">
              <pdfaProperty:name>DocumentType</pdfaProperty:name>
              <pdfaProperty:valueType>Text</pdfaProperty:valueType>
              <pdfaProperty:category>external</pdfaProperty:category>
              <pdfaProperty:description>INVOICE</pdfaProperty:description>
            </rdf:li>
              <rdf:li rdf:parseType="Resource">
              <pdfaProperty:name>Version</pdfaProperty:name>
              <pdfaProperty:valueType>Text</pdfaProperty:valueType>
              <pdfaProperty:category>external</pdfaProperty:category>
              <pdfaProperty:description>The actual version of the ZUGFeRD data</pdfaProperty:description>
            </rdf:li>
              <rdf:li rdf:parseType="Resource">
              <pdfaProperty:name>ConformanceLevel</pdfaProperty:name>
              <pdfaProperty:valueType>Text</pdfaProperty:valueType>
              <pdfaProperty:category>external</pdfaProperty:category>
              <pdfaProperty:description>The conformance level of the ZUGFeRD data</pdfaProperty:description>
            </rdf:li>
          </rdf:Seq>
        </pdfaSchema:property>
      </rdf:li>
    </rdf:Bag>
  </pdfaExtension:schemas>
</rdf:Description>
''';
  }
}

class _DateFormat {
  String format({
    required DateTime dt,
    bool asIso = false,
  }) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    if (asIso) {
      // "yyyy-MM-dd'T'HH:mm:ss"
      return '$year-$month-${day}T$hour:$minute:$second';
    }
    // "yyyyMMddHHmmss"
    return '$year$month$day$hour$minute$second';
  }
}
