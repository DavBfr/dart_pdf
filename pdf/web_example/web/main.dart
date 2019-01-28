import 'dart:convert';
import 'dart:html';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

void main() {
  final ButtonElement generateButton = querySelector('#generate');

  generateButton.onClick.listen((_) async {
    final String data = Uri.encodeComponent(base64.encode(buildPdf()));

    final ObjectElement doc = querySelector('#doc');
    doc.data = 'data:application/pdf;base64,$data';
  });
}

List<int> buildPdf() {
  final Document pdf = Document();

  pdf.addPage(Page(build: (Context ctx) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        child: Text(
          'Hello!',
          style: TextStyle(color: PdfColors.blueGrey),
        ),
      ),
    );
  }));

  return pdf.save();
}
