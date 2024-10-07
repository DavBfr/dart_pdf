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
