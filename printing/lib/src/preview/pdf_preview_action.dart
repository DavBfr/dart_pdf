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

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../callback.dart';

/// Base Action callback
typedef OnPdfPreviewActionPressed = void Function(
  BuildContext context,
  LayoutCallback build,
  PdfPageFormat pageFormat,
);

/// Action to add the the [PdfPreview] widget
class PdfPreviewAction {
  /// Represents an icon to add to [PdfPreview]
  const PdfPreviewAction({
    required this.icon,
    required this.onPressed,
  });

  /// The icon to display
  final Icon icon;

  /// The callback called when the user tap on the icon
  final OnPdfPreviewActionPressed? onPressed;
}
