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
import 'dart:typed_data';

import 'callback.dart';
import 'raster.dart';

/// Represents a print job to communicate with the platform implementation
class PrintJob {
  /// Create a print job
  PrintJob({
    this.onLayout,
    this.onHtmlRendered,
    this.onCompleted,
    this.onPageRasterized,
  });

  /// Callback used when calling Printing.layoutPdf()
  final LayoutCallback onLayout;

  /// Callback used when calling Printing.convertHtml()
  final Completer<Uint8List> onHtmlRendered;

  /// Future triggered when the job is done
  final Completer<bool> onCompleted;

  /// Stream of rasterized pages
  final StreamController<PdfRaster> onPageRasterized;

  /// The Job number
  int index;
}
