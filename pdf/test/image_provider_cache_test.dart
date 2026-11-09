import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

class _TrackingImage extends pw.ImageProvider {
  _TrackingImage() : super(300, 200, PdfImageOrientation.topLeft, null);

  final requests = <(int?, int?)>[];

  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) {
    requests.add((width, height));
    return PdfImage(
      context.document,
      image: Uint8List.fromList([255, 0, 0, 255]),
      width: 1,
      height: 1,
    );
  }
}

void main() {
  test('an initial full-resolution render does not disable later DPI sizing', () {
    final image = _TrackingImage();
    final firstDocument = PdfDocument();
    final context = pw.Context(document: firstDocument);
    const fullPage = PdfPoint(72, 72);
    const halfPage = PdfPoint(72, 36);

    final original = image.resolve(context, fullPage);
    final scaled = image.resolve(context, fullPage, dpi: 72);
    expect(identical(original, scaled), isFalse);
    expect(image.requests, [(null, null), (72, 72)]);

    final cached = image.resolve(context, fullPage, dpi: 72);
    expect(identical(cached, scaled), isTrue);
    expect(image.requests.length, 2);

    // Reuse must also depend on height, not only width.
    image.resolve(context, halfPage, dpi: 72);
    expect(image.requests, [(null, null), (72, 72), (72, 36)]);

    // Cached PDF image objects belong to their original document.
    final other = pw.Context(document: PdfDocument());
    final otherImage = image.resolve(other, fullPage, dpi: 72);
    expect(identical(otherImage, scaled), isFalse);
    expect(image.requests.length, 4);
  });
}
