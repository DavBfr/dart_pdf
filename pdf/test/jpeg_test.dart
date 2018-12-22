import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import "package:test/test.dart";

Future<Uint8List> download(String url) async {
  var client = HttpClient();
  var request = await client.getUrl(Uri.parse(url));
  var response = await request.close();
  var builder = await response.fold(BytesBuilder(), (b, d) => b..add(d));
  var data = builder.takeBytes();
  return Uint8List.fromList(data);
}

void main() {
  test('Pdf1', () async {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);

    var image = PdfImage(pdf,
        image: await download("https://www.nfet.net/nfet.jpg"),
        width: 472,
        height: 477,
        jpeg: true,
        alpha: false);

    var g = page.getGraphics();
    g.drawImage(image, 30.0, page.pageFormat.height - 507.0);

    var file = File('file4.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
