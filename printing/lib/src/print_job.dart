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

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'callback.dart';
import 'raster.dart';

/// Represents a print job to communicate with the platform implementation
class PrintJob {
  /// Create a print job
  const PrintJob._({
    required this.index,
    this.onLayout,
    this.onHtmlRendered,
    this.onCompleted,
    this.onPageRasterized,
    this.format,
  });

  /// Callback used when calling Printing.layoutPdf()
  final LayoutCallback? onLayout;

  /// Callback used when calling Printing.convertHtml()
  final Completer<Uint8List>? onHtmlRendered;

  /// Future triggered when the job is done
  final Completer<bool>? onCompleted;

  /// Stream of rasterized pages
  final StreamController<PdfRaster>? onPageRasterized;

  /// The page format this job was requested with
  ///
  /// Used to repair a page size the platform reports back as not finite.
  final PdfPageFormat? format;

  /// The Job number
  final int index;
}

/// Represents a list of print jobs
class PrintJobs {
  /// Create a list print jobs
  PrintJobs();

  static int _currentIndex = Random().nextInt(0x7FFFFFFF);

  final _printJobs = <int, PrintJob>{};

  /// Add a print job to the list
  PrintJob add({
    LayoutCallback? onLayout,
    Completer<Uint8List>? onHtmlRendered,
    Completer<bool>? onCompleted,
    StreamController<PdfRaster>? onPageRasterized,
    PdfPageFormat? format,
  }) {
    final job = PrintJob._(
      index: _currentIndex++,
      onLayout: onLayout,
      onHtmlRendered: onHtmlRendered,
      onCompleted: onCompleted,
      onPageRasterized: onPageRasterized,
      format: format,
    );
    _printJobs[job.index] = job;
    return job;
  }

  /// Retrieve an existing job
  PrintJob? getJob(int index) {
    return _printJobs[index];
  }

  /// remove a print job from the list
  void remove(int index) {
    _printJobs.remove(index);
  }

  /// Number of jobs still waiting for a platform callback.
  ///
  /// Every call registers one job and must unregister it again, whether it
  /// succeeds or fails, so this returns to its previous value after each
  /// completed call.
  int get pending => _printJobs.length;
}
