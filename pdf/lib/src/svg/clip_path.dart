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

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'brush.dart';
import 'operation.dart';
import 'painter.dart';

@immutable
class SvgClipPath {
  const SvgClipPath(this.children, this.isEmpty, this.painter);

  factory SvgClipPath.fromXml(
      XmlElement element, SvgPainter painter, SvgBrush brush) {
    final clipPathAttr = element.getAttribute('clip-path');
    if (clipPathAttr == null) {
      return const SvgClipPath(null, true, null);
    }

    Iterable<SvgOperation?> children;

    if (clipPathAttr.startsWith('url(#')) {
      final id = clipPathAttr.substring(5, clipPathAttr.lastIndexOf(')'));
      final clipPath = painter.parser.findById(id);
      if (clipPath != null) {
        children = clipPath.children
            .whereType<XmlElement>()
            .map<SvgOperation?>((c) => SvgOperation.fromXml(c, painter, brush));
        return SvgClipPath(children, false, painter);
      }
    }

    return const SvgClipPath(null, true, null);
  }

  final Iterable<SvgOperation?>? children;

  final bool isEmpty;

  final SvgPainter? painter;

  bool get isNotEmpty => !isEmpty;

  void apply(PdfGraphics canvas) {
    if (isEmpty) {
      return;
    }

    for (final child in children!) {
      child!.draw(canvas);
    }
    canvas.clipPath();
  }
}
