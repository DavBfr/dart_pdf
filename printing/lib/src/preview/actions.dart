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

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../printing.dart';
import 'controller.dart';

/// Base Action callback
typedef OnPdfPreviewActionPressed = void Function(
  BuildContext context,
  LayoutCallback build,
  PdfPageFormat pageFormat,
);

mixin PdfPreviewActionBounds {
  final childKey = GlobalKey();

  /// Calculate the widget bounds for iPad popup position
  Rect get bounds {
    final referenceBox =
        childKey.currentContext!.findRenderObject() as RenderBox;
    final topLeft =
        referenceBox.localToGlobal(referenceBox.paintBounds.topLeft);
    final bottomRight =
        referenceBox.localToGlobal(referenceBox.paintBounds.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// Action to add the the [PdfPreview] widget
class PdfPreviewAction extends StatelessWidget {
  /// Represents an icon to add to [PdfPreview]
  const PdfPreviewAction({
    Key? key,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  /// The icon to display
  final Widget icon;

  /// The callback called when the user tap on the icon
  final OnPdfPreviewActionPressed? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      onPressed: onPressed == null ? null : () => pressed(context),
    );
  }

  Future<void> pressed(BuildContext context) async {
    final data = PdfPreviewController.of(context);
    onPressed!(context, data.buildDocument, data.pageFormat);
  }
}

class PdfPrintAction extends StatelessWidget {
  const PdfPrintAction({
    Key? key,
    Widget? icon,
    String? jobName,
    this.onPrinted,
    this.onPrintError,
    this.dynamicLayout = true,
    this.usePrinterSettings = false,
  })  : icon = icon ?? const Icon(Icons.print),
        jobName = jobName ?? 'Document',
        super(key: key);

  final Widget icon;

  final String jobName;

  /// Request page re-layout to match the printer paper and margins.
  /// Mitigate an issue with iOS and macOS print dialog that prevent any
  /// channel message while opened.
  final bool dynamicLayout;

  /// Set [usePrinterSettings] to true to use the configuration defined by
  /// the printer. May not work for all the printers and can depend on the
  /// drivers. (Supported platforms: Windows)
  final bool usePrinterSettings;

  /// Called if the user prints the pdf document
  final VoidCallback? onPrinted;

  /// Called if an error creating the Pdf occurred
  final void Function(dynamic error)? onPrintError;

  @override
  Widget build(BuildContext context) {
    return PdfPreviewAction(
      icon: icon,
      onPressed: _print,
    );
  }

  Future<void> _print(
    BuildContext context,
    LayoutCallback build,
    PdfPageFormat pageFormat,
  ) async {
    final data = PdfPreviewController.of(context);

    try {
      final result = await Printing.layoutPdf(
        onLayout: build,
        name: jobName,
        format: data.actualPageFormat,
        dynamicLayout: dynamicLayout,
        usePrinterSettings: usePrinterSettings,
      );

      if (result) {
        onPrinted?.call();
      }
    } catch (exception, stack) {
      InformationCollector? collector;

      assert(() {
        collector = () sync* {
          yield StringProperty('PageFormat', data.actualPageFormat.toString());
        };
        return true;
      }());

      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'printing',
        context: ErrorDescription('while printing a PDF'),
        informationCollector: collector,
      ));

      onPrintError?.call(exception);
    }
  }
}

class PdfShareAction extends StatelessWidget with PdfPreviewActionBounds {
  PdfShareAction({
    Key? key,
    Widget? icon,
    String? filename,
    this.subject,
    this.body,
    this.emails,
    this.onShared,
    this.onShareError,
  })  : icon = icon ?? const Icon(Icons.share),
        filename = filename ?? 'document.pdf',
        super(key: key);

  final Widget icon;

  final String filename;

  /// email subject when email application is selected from the share dialog
  final String? subject;

  /// extra text to share with Pdf document
  final String? body;

  /// list of email addresses which will be filled automatically if the email application
  /// is selected from the share dialog.
  /// This will work only for Android platform.
  final List<String>? emails;

  /// Called if the user prints the pdf document
  final VoidCallback? onShared;

  /// Called if an error creating the Pdf occurred
  final void Function(dynamic error)? onShareError;

  @override
  Widget build(BuildContext context) {
    return PdfPreviewAction(
      key: childKey,
      icon: icon,
      onPressed: _share,
    );
  }

  Future<void> _share(
    BuildContext context,
    LayoutCallback build,
    PdfPageFormat pageFormat,
  ) async {
    final bytes = await build(pageFormat);

    final result = await Printing.sharePdf(
      bytes: bytes,
      bounds: bounds,
      filename: filename,
      body: body,
      subject: subject,
      emails: emails,
    );

    if (result) {
      onShared?.call();
    }
  }
}

class PdfPageFormatAction extends StatelessWidget {
  const PdfPageFormatAction({
    Key? key,
    required this.pageFormats,
  }) : super(key: key);

  /// List of page formats the user can choose
  final Map<String, PdfPageFormat> pageFormats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.primaryIconTheme.color ?? Colors.white;
    final data = PdfPreviewController.listen(context);
    final allPageFormats = <String, PdfPageFormat>{...pageFormats};

    var format = data.pageFormat;
    final orientation = data.horizontal;

    if (!allPageFormats.values.contains(data.pageFormat)) {
      var found = false;
      for (final f in allPageFormats.values) {
        if (format.portrait == f.portrait) {
          format = f;
          found = true;
          break;
        }
      }
      if (!found) {
        allPageFormats['---'] = format;
      }
    }

    final keys = allPageFormats.keys.toList()..sort();

    return DropdownButton<PdfPageFormat>(
      dropdownColor: theme.primaryColor,
      icon: Icon(
        Icons.arrow_drop_down,
        color: iconColor,
      ),
      value: format,
      items: List<DropdownMenuItem<PdfPageFormat>>.generate(
        allPageFormats.length,
        (int index) {
          final key = keys[index];
          final val = allPageFormats[key]!;
          return DropdownMenuItem<PdfPageFormat>(
            value: val,
            child: Text(key, style: TextStyle(color: iconColor)),
          );
        },
      ),
      onChanged: (PdfPageFormat? pageFormat) {
        if (pageFormat != null) {
          data.pageFormat =
              orientation ? pageFormat.landscape : pageFormat.portrait;
        }
      },
    );
  }
}

class PdfPageOrientationAction extends StatelessWidget {
  const PdfPageOrientationAction({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.primaryIconTheme.color ?? Colors.white;
    final data = PdfPreviewController.listen(context);
    final horizontal = data.horizontal;

    final disabledColor = iconColor.withAlpha(120);
    return ToggleButtons(
      renderBorder: false,
      borderColor: disabledColor,
      color: disabledColor,
      selectedBorderColor: iconColor,
      selectedColor: iconColor,
      onPressed: (int index) {
        data.horizontal = index == 1;
      },
      isSelected: <bool>[horizontal == false, horizontal == true],
      children: <Widget>[
        Transform.rotate(
          angle: -math.pi / 2,
          child: const Icon(
            Icons.note_outlined,
          ),
        ),
        const Icon(Icons.note_outlined),
      ],
    );
  }
}
