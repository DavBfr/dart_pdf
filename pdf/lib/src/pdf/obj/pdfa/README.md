Here are some classes to help you creating PDF/A compliant PDFs
plus embedding Facturx invoices.

### Rules

1. Your PDF must only use embedded Fonts,
2. For now you cannot use any Annotations in your PDF
3. You must include a special Meta-XML, use below "PdfaRdf" and put the reuslting XML document into your documents metadata
4. You must include a Colorprofile, use the below "PdfaColorProfile" and embed the contents of "sRGB2014.icc"
5. Optionally attach an InvoiceXML using "PdfaFacturxRdf" and "PdfaAttachedFiles"

### Example

```
pw.Document pdf = pw.Document(
  ...
  metadata: PdfaRdf(
    ...
    invoiceRdf: PdfaFacturxRdf().create()
  ).create(),
);

PdfaColorProfile(
  pdf.document,
  File('sRGB2014.icc').readAsBytesSync(),
);

PdfaAttachedFiles(
  pdf.document,
  {
    'factur-x.xml': myInvoiceXmlDocument,
  },
);
```

### Validating

https://demo.verapdf.org
https://avepdf.com/pdfa-validation
https://www.mustangproject.org
