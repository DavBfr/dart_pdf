import 'package:xml/xml.dart';

import 'pdfa_date_format.dart';

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
    var createDate = PdfaDateFormat().format(dt: creationDate, asIso: true);
    final offset = creationDate.timeZoneOffset;
    final hours = offset.inHours > 0
        ? offset.inHours
        : 1; // For fixing divide by 0
    if (!offset.isNegative) {
      createDate =
          "$createDate+${offset.inHours.toString().padLeft(2, '0')}:${(offset.inMinutes % (hours * 60)).toString().padLeft(2, '0')}";
    } else {
      createDate =
          "$createDate-${(-offset.inHours).toString().padLeft(2, '0')}:${(offset.inMinutes % (hours * 60)).toString().padLeft(2, '0')}";
    }

    // Caller values are text nodes, never XML source. They used to be
    // interpolated straight into this template, so an unmatched '<' threw an
    // XmlParserException out of the build, balanced markup was injected into the
    // packet - including over the pdfaid conformance claim - and an
    // entity-looking value was resolved into something else. Dart interpolation
    // also calls toString(), so every unset field wrote the word 'null': the
    // package's own README example emitted <pdf:Producer>null</pdf:Producer>.
    //
    // An element is omitted when its value is null rather than emitted empty: an
    // empty rdf:Alt is not a valid dc:title.
    String? text(String? value) =>
        value == null ? null : XmlText(_clean(value)).toXmlString();

    final producerText = text(producer);
    final keywordsText = text(keywords);
    final creatorText = text(creator);
    final authorText = text(author);
    final titleText = text(title);
    final subjectText = text(subject);

    final pdfProperties = <String>[
      if (producerText != null) '<pdf:Producer>$producerText</pdf:Producer>',
      if (keywordsText != null) '<pdf:Keywords>$keywordsText</pdf:Keywords>',
    ];

    final dcProperties = <String>[
      if (authorText != null)
        '<dc:creator><rdf:Seq><rdf:li>$authorText</rdf:li></rdf:Seq></dc:creator>',
      if (titleText != null)
        '<dc:title><rdf:Alt><rdf:li xml:lang="x-default">$titleText</rdf:li></rdf:Alt></dc:title>',
      if (subjectText != null)
        '<dc:description><rdf:Alt><rdf:li xml:lang="x-default">$subjectText</rdf:li></rdf:Alt></dc:description>',
    ];

    return XmlDocument.parse('''
<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
${pdfProperties.isEmpty ? '' : '''  <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
    ${pdfProperties.join('\n    ')}
  </rdf:Description>'''}
  <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
    <xmp:CreateDate>$createDate</xmp:CreateDate>
${creatorText == null ? '' : '    <xmp:CreatorTool>$creatorText</xmp:CreatorTool>'}
  </rdf:Description>
${dcProperties.isEmpty ? '' : '''  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
    ${dcProperties.join('\n    ')}
  </rdf:Description>'''}
  <rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
    <pdfaid:part>3</pdfaid:part>
    <pdfaid:conformance>B</pdfaid:conformance>
  </rdf:Description>
  
  $invoiceRdf
  
</rdf:RDF>
<?xpacket end="r"?>
''');
  }

  /// Drop the characters XML 1.0 forbids in content.
  ///
  /// Escaping alone would leave a NUL or a stray control character in the packet,
  /// which no parser will read back.
  static String _clean(String value) =>
      value.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');
}
