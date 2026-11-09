import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  test('page number lookup is stable across repeated reads and copies', () {
    final doc = PdfDocument();
    final first = PdfPage(doc);
    final second = PdfPage(doc);
    final context = pw.Context(document: doc, page: second);
    expect(context.pageNumber, 2);
    for (var i = 0; i < 500; i++) {
      expect(context.pageNumber, 2);
      expect(context.pageLabel, '2');
    }
    expect(context.copyWith().pageNumber, 2);
    expect(pw.Context(document: doc, page: first).pageNumber, 1);
  });

  test('cached page number is invalidated when a page is inserted ahead', () {
    final doc = PdfDocument();
    PdfPage(doc);
    final target = PdfPage(doc);
    final context = pw.Context(document: doc, page: target);
    expect(context.pageNumber, 2);

    final inheritedContext = context.copyWith();
    final inserted = PdfPage(doc, index: 1);
    expect(context.pageNumber, 3);
    expect(inheritedContext.pageNumber, 3);
    expect(pw.Context(document: doc, page: inserted).pageNumber, 2);

    final other = PdfPage(doc);
    expect(context.copyWith(page: other).pageNumber, 4);
    expect(context.pageNumber, 3);
  });
}
