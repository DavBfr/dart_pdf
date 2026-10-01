/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// An image provider that counts how often it is asked to build.
class CountingImage extends ImageProvider {
  CountingImage({double? dpi})
    : super(200, 200, PdfImageOrientation.topLeft, dpi);

  int builds = 0;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    builds++;
    return PdfImage.fromImage(
      context.document,
      image: im.Image(
        width: width ?? 200,
        height: height ?? 200,
        numChannels: 3,
      ),
    );
  }
}

/// Resolve [provider] in its own document at [size] and hand both back.
Future<Document> resolveIn(
  ImageProvider provider,
  double size, {
  int times = 1,
  void Function(PdfImage image)? onImage,
}) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(600, 600, marginAll: 0),
      build: (Context context) {
        for (var i = 0; i < times; i++) {
          final image = provider.resolve(context, PdfPoint(size, size));
          onImage?.call(image);
        }
        return SizedBox();
      },
    ),
  );
  await document.save();
  return document;
}

void main() {
  group('the image cache', () {
    test('does not outlive the document it was built for', () async {
      // The cache was an unbounded map on the provider, keyed only by the pixel
      // width, and a PdfImage holds its PdfDocument - which holds every page,
      // font and content stream. One long-lived provider leaked roughly a
      // finished document per distinct layout width.
      final provider = CountingImage(dpi: 72);
      final references = <WeakReference<PdfDocument>>[];

      for (var i = 0; i < 5; i++) {
        final document = await resolveIn(provider, 20.0 + i * 10);
        references.add(WeakReference<PdfDocument>(document.document));
      }

      expect(provider.builds, 5, reason: 'five distinct widths');

      // Churn enough to make the collector run.
      for (var i = 0; i < 40; i++) {
        final waste = Uint8List(1 << 20);
        waste[0] = i;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (var i = 0; i < 40; i++) {
        final waste = Uint8List(1 << 20);
        waste[0] = i;
      }

      final alive = references.where((r) => r.target != null).length;
      expect(alive, 0, reason: '$alive of 5 documents are still reachable');
    });

    test('is per document', () async {
      final provider = CountingImage();
      late PdfDocument first;
      late PdfDocument second;

      final a = await resolveIn(
        provider,
        100,
        times: 2,
        onImage: (PdfImage image) => first = image.pdfDocument,
      );
      final b = await resolveIn(
        provider,
        100,
        onImage: (PdfImage image) => second = image.pdfDocument,
      );

      expect(
        provider.builds,
        2,
        reason: 'once per document, not once per call',
      );
      expect(identical(first, a.document), isTrue);
      expect(identical(second, b.document), isTrue);
      expect(provider.debugCacheLength(a.document), 1);
      expect(provider.debugCacheLength(b.document), 1);
    });

    test('still deduplicates inside one document', () async {
      final provider = CountingImage();
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(600, 600, marginAll: 0),
          build: (Context context) => Column(
            children: <Widget>[
              SizedBox(width: 100, height: 100, child: Image(provider)),
              SizedBox(width: 100, height: 100, child: Image(provider)),
            ],
          ),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      expect(provider.builds, 1);
      // Both draws name the same XObject, and the page declares it once. (A
      // second image object exists, but it is this one's soft mask.)
      expect(
        RegExp(r'/I\d+ Do').allMatches(pdf).map((m) => m.group(0)).toSet(),
        hasLength(1),
      );
      expect(RegExp(r'/XObject<<[^>]*>>').allMatches(pdf), hasLength(1));
      expect(RegExp(r'/XObject<<(/I\d+ \d+ 0 R)>>').hasMatch(pdf), isTrue);
    });
  });

  group('an ImageProxy', () {
    /// Run [body] with a Context belonging to [document].
    Future<void> withContext(
      Document document,
      void Function(Context context) body,
    ) async {
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(600, 600, marginAll: 0),
          build: (Context context) {
            body(context);
            return SizedBox();
          },
        ),
      );
      await document.save();
    }

    test('refuses a PdfImage from another document', () async {
      // resolve() did notice the mismatch, and answered it by calling buildImage
      // again - which hands back the same foreign image. Document A's object
      // number then landed in document B's /XObject dictionary, and the viewer
      // drew nothing, with no error anywhere.
      final other = Document(compress: false);
      late PdfImage foreign;
      await withContext(other, (Context context) {
        foreign = PdfImage.fromImage(
          context.document,
          image: im.Image(width: 10, height: 10, numChannels: 3),
        );
      });

      final document = Document(compress: false);
      Object? thrown;
      await withContext(document, (Context context) {
        try {
          ImageProxy(foreign).resolve(context, const PdfPoint(100, 100));
        } catch (e) {
          thrown = e;
        }
      });

      expect(thrown, isA<PdfException>());
      expect(thrown.toString(), contains('another PdfDocument'));
    });

    test('returns the very same image inside its own document', () async {
      final document = Document(compress: false);
      await withContext(document, (Context context) {
        final image = PdfImage.fromImage(
          context.document,
          image: im.Image(width: 10, height: 10, numChannels: 3),
        );

        expect(
          identical(
            ImageProxy(image).resolve(context, const PdfPoint(100, 100)),
            image,
          ),
          isTrue,
        );
      });
    });
  });

  test(
    'every image XObject reference resolves inside its own document',
    () async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(600, 600, marginAll: 0),
          build: (Context context) => Image(CountingImage()),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      final names = RegExp(r'/I(\d+) (\d+) 0 R').allMatches(pdf);
      expect(names, isNotEmpty);

      for (final name in names) {
        final objser = name.group(2);
        final body = RegExp(
          '\\n$objser 0 obj(.*?)endobj',
          dotAll: true,
        ).firstMatch(pdf);

        expect(body, isNotNull, reason: 'object $objser is in this document');
        expect(body!.group(1), contains('/Subtype/Image'));
      }
    },
  );
}
