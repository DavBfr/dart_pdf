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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../raster.dart';

/// Represents one PDF page
class PdfPreviewPage extends StatelessWidget {
  /// Create a PDF page widget
  const PdfPreviewPage({
    Key? key,
    this.page,
    this.pdfPreviewPageDecoration,
    this.pageMargin,
  }) : super(key: key);

  /// Image representing the content of the page
  final PdfRaster? page;

  /// Decoration around the page
  final Decoration? pdfPreviewPageDecoration;

  /// Margin
  final EdgeInsets? pageMargin;

  @override
  Widget build(BuildContext context) {
    final im = PdfRasterImage(page!);
    final scrollbarTrack = Theme.of(context)
            .scrollbarTheme
            .thickness
            ?.resolve({MaterialState.hovered}) ??
        12;

    return Container(
      margin: pageMargin ??
          EdgeInsets.only(
            left: 8 + scrollbarTrack,
            top: 8,
            right: 8 + scrollbarTrack,
            bottom: 12,
          ),
      decoration: pdfPreviewPageDecoration ??
          const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                offset: Offset(0, 3),
                blurRadius: 5,
                color: Color(0xFF000000),
              ),
            ],
          ),
      child: AspectRatio(
        aspectRatio: page!.width / page!.height,
        child: Image(
          image: im,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
