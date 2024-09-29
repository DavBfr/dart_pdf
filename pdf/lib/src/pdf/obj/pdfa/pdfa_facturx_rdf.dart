class PdfaFacturxRdf {
  String create(
      {String filename = 'factur-x.xml',
      String namespace = 'urn:cen.eu:invoice:1p0:schema#'}) {
    // String namespace = 'urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#';
    // String namespace = 'urn:cen.eu:invoice:1p0:schema#';
    // String filename = 'factur-x.xml';
    // String filename = 'xrechnung.xml';

    return '''
    
<rdf:Description xmlns:fx="$namespace" rdf:about="">
  <fx:DocumentType>INVOICE</fx:DocumentType>
  <fx:DocumentFileName>$filename</fx:DocumentFileName>
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
        <pdfaSchema:schema>Invoice PDFA Extension Schema</pdfaSchema:schema>
        <pdfaSchema:namespaceURI>$namespace</pdfaSchema:namespaceURI>
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
