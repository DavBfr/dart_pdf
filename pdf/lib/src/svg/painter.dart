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

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import '../widgets/font.dart';
import '../widgets/svg.dart';
import 'brush.dart';
import 'color.dart';
import 'group.dart';
import 'operation.dart';
import 'parser.dart';

class SvgPainter {
  SvgPainter(
    this.parser,
    this._canvas,
    this.document,
    this.boundingBox, {
    this.customFontLookup,
  });

  final SvgParser parser;

  final PdfGraphics? _canvas;

  final PdfDocument document;

  final PdfRect boundingBox;

  final SvgCustomFontLookup? customFontLookup;

  /// The viewport a percentage length is a fraction of.
  ///
  /// Seeded from the root viewBox and replaced while a nested viewport paints.
  /// Geometry attributes are parsed lazily, inside the paint of the element that
  /// contains them, so the value in force while a child is built is the one that
  /// child belongs to.
  PdfPoint viewport = PdfPoint.zero;

  /// [boundingBox], mapped back into the space [canvas] is currently drawing in.
  ///
  /// boundingBox is in page points, and a soft mask's Form XObject is evaluated
  /// under the SVG user-space CTM - so handing it over as the /BBox clipped the
  /// mask to the first pageWidth x pageHeight *user units*. With a viewBox of
  /// 1024 on A4 that is a corner of the artwork; everything else fell into the
  /// /Luminosity black backdrop and came out at alpha 0.
  PdfRect userSpaceBoundingBox(PdfGraphics canvas) {
    final inverse = canvas.getTransform();
    if (inverse.invert() == 0) {
      return boundingBox; // Singular: nothing better to say.
    }

    final corners = <Vector3>[
      inverse.transform3(Vector3(boundingBox.left, boundingBox.bottom, 0)),
      inverse.transform3(Vector3(boundingBox.right, boundingBox.bottom, 0)),
      inverse.transform3(Vector3(boundingBox.right, boundingBox.top, 0)),
      inverse.transform3(Vector3(boundingBox.left, boundingBox.top, 0)),
    ];

    final xs = corners.map((Vector3 c) => c.x);
    final ys = corners.map((Vector3 c) => c.y);

    return PdfRect.fromLBRT(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  /// Run [body] with [viewport] in force, then put back what was there.
  void withViewport(PdfPoint size, void Function() body) {
    final previous = viewport;
    viewport = size;
    try {
      body();
    } finally {
      viewport = previous;
    }
  }

  void paint() {
    viewport = parser.viewBox.size;

    final brush = parser.colorFilter == null
        ? SvgBrush.defaultContext
        : SvgBrush.defaultContext.copyWith(
            fill: SvgColor(color: parser.colorFilter),
          );

    // The root never goes through SvgOperation.fromXml, so its own display and
    // visibility were never tested at all.
    if (SvgOperation.isHidden(parser.root)) {
      return;
    }

    SvgGroup.fromXml(parser.root, this, brush).paint(_canvas!);
  }

  final _fontCache = <String, Font>{};

  Font? getFontCache(String fontFamily, String fontStyle, String fontWeight) {
    final cache = '$fontFamily-$fontStyle-$fontWeight';

    if (!_fontCache.containsKey(cache)) {
      _fontCache[cache] = getFont(fontFamily, fontStyle, fontWeight);
    }

    return _fontCache[cache];
  }

  Font getFont(String fontFamily, String fontStyle, String fontWeight) {
    final customFont = customFontLookup?.call(
      fontFamily,
      fontStyle,
      fontWeight,
    );
    if (customFont != null) {
      return customFont;
    }

    switch (fontFamily) {
      case 'serif':
        switch (fontStyle) {
          case 'normal':
            switch (fontWeight) {
              case 'normal':
              case 'lighter':
                return Font.times();
            }
            return Font.timesBold();
        }
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.timesItalic();
        }
        return Font.timesBoldItalic();

      case 'monospace':
        switch (fontStyle) {
          case 'normal':
            switch (fontWeight) {
              case 'normal':
              case 'lighter':
                return Font.courier();
            }
            return Font.courierBold();
        }
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.courierOblique();
        }
        return Font.courierBoldOblique();
    }

    switch (fontStyle) {
      case 'normal':
        switch (fontWeight) {
          case 'normal':
          case 'lighter':
            return Font.helvetica();
        }
        return Font.helveticaBold();
    }
    switch (fontWeight) {
      case 'normal':
      case 'lighter':
        return Font.helveticaOblique();
    }
    return Font.helveticaBoldOblique();
  }
}
