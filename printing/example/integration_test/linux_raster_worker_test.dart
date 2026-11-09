import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The raster worker is Linux-specific.
  final skip = !Platform.isLinux;

  testWidgets(
    'Linux raster keeps the Dart event loop responsive',
    (tester) async {
      final document = pw.Document();
      for (var page = 0; page < 60; page++) {
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Text('Raster worker page $page'),
            ),
          ),
        );
      }
      final bytes = await document.save();

      var timerTicks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => timerTicks++,
      );

      var rasterized = 0;
      final stopwatch = Stopwatch()..start();
      await for (final _ in Printing.raster(bytes, dpi: 144)) {
        rasterized++;
      }
      stopwatch.stop();
      timer.cancel();

      expect(rasterized, 60);
      // Rastering dozens of A4 pages is deliberately long enough that a
      // synchronous native method handler starves this timer completely.
      expect(
        timerTicks,
        greaterThan(2),
        reason: 'Dart timer did not run while native rastering took '
            '${stopwatch.elapsedMilliseconds} ms',
      );
    },
    skip: skip,
  );

  testWidgets(
    'Malformed PDF fails promptly and native state can be reused',
    (tester) async {
      final malformed = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      await expectLater(
        Printing.raster(Uint8List(0))
            .toList()
            .timeout(const Duration(seconds: 15)),
        throwsA(isNot(isA<TimeoutException>())),
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        await expectLater(
          Printing.raster(malformed)
              .toList()
              .timeout(const Duration(seconds: 15)),
          throwsA(isNot(isA<TimeoutException>())),
        );
      }

      final document = pw.Document();
      document.addPage(
        pw.Page(
          build: (_) => pw.Center(child: pw.Text('Recovery')),
        ),
      );
      final valid = await document.save();
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(
          await Printing.raster(valid)
              .length
              .timeout(const Duration(seconds: 15)),
          1,
        );
      }
    },
    skip: skip,
  );

  testWidgets(
    'Cancelling a Dart raster subscription does not poison later jobs',
    (tester) async {
      final document = pw.Document();
      for (var i = 0; i < 12; i++) {
        document.addPage(
          pw.Page(
            build: (_) => pw.Center(child: pw.Text('Cancellation $i')),
          ),
        );
      }
      final bytes = await document.save();
      final first = await Printing.raster(bytes, dpi: 144)
          .take(1)
          .toList()
          .timeout(const Duration(seconds: 20));
      expect(first, hasLength(1));

      // The native raster task is allowed to finish; the next task must still
      // complete normally even if Dart cancelled its page subscription.
      final pages = await Printing.raster(bytes)
          .toList()
          .timeout(const Duration(seconds: 30));
      expect(pages, hasLength(12));
    },
    skip: skip,
  );
}
