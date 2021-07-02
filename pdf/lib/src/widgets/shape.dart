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

import 'package:pdf/src/widgets/basic.dart';
import 'package:pdf/src/widgets/geometry.dart';
import 'package:pdf/src/widgets/widget.dart';

import '../../pdf.dart';

class Circle extends Widget {
  Circle({required this.width, required this.height});

  final double width;
  final double height;

  @override
  void layout(Context context, BoxConstraints constraints, {bool parentUsesSize = false}) {
    final sizes = applyBoxFit(BoxFit.contain, PdfPoint(width, height), PdfPoint(width, height));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination!);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    context.canvas
      ..saveContext()
      ..setStrokeColor(PdfColors.amber)
      ..setFillColor(PdfColors.orange)
      ..drawEllipse(box!.width / 2, box!.height / 2, box!.width / 2, box!.height / 2)
      ..fillAndStrokePath()
      ..restoreContext();
  }
}
