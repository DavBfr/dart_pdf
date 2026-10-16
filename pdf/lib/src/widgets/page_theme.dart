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

import '../../pdf.dart';
import 'geometry.dart';
import 'page.dart';
import 'text.dart';
import 'theme.dart';

@immutable
class PageTheme {
  const PageTheme({
    PdfPageFormat? pageFormat,
    this.buildBackground,
    this.buildForeground,
    this.theme,
    PageOrientation? orientation,
    EdgeInsetsGeometry? margin,
    this.clip = false,
    this.textDirection,
  }) : pageFormat = pageFormat ?? PdfPageFormat.standard,
       orientation = orientation ?? PageOrientation.natural,
       _margin = margin;

  final PdfPageFormat pageFormat;

  final PageOrientation orientation;

  final EdgeInsetsGeometry? _margin;

  final BuildCallback? buildBackground;

  final BuildCallback? buildForeground;

  final ThemeData? theme;

  final bool clip;

  final TextDirection? textDirection;

  bool get mustRotate =>
      (orientation == PageOrientation.landscape &&
          pageFormat.height > pageFormat.width) ||
      (orientation == PageOrientation.portrait &&
          pageFormat.width > pageFormat.height);

  EdgeInsetsGeometry? get margin {
    if (_margin != null) {
      if (mustRotate) {
        // Rotating needs physical edges, so a directional margin is resolved
        // here - and only here. Resolving it before the test threw on any theme
        // with a directional margin and no textDirection of its own, because
        // EdgeInsetsDirectional.resolve asserts on a null direction. ltr is the
        // fallback Directionality.of uses.
        final resolved = _margin.resolve(textDirection ?? TextDirection.ltr);
        return EdgeInsets.fromLTRB(
          resolved.bottom,
          resolved.left,
          resolved.top,
          resolved.right,
        );
      } else {
        return _margin;
      }
    }

    if (mustRotate) {
      return EdgeInsets.fromLTRB(
        pageFormat.marginBottom,
        pageFormat.marginLeft,
        pageFormat.marginTop,
        pageFormat.marginRight,
      );
    } else {
      return EdgeInsets.fromLTRB(
        pageFormat.marginLeft,
        pageFormat.marginTop,
        pageFormat.marginRight,
        pageFormat.marginBottom,
      );
    }
  }

  PageTheme copyWith({
    PdfPageFormat? pageFormat,
    BuildCallback? buildBackground,
    BuildCallback? buildForeground,
    ThemeData? theme,
    PageOrientation? orientation,
    EdgeInsetsGeometry? margin,
    bool? clip,
    TextDirection? textDirection,
  }) => PageTheme(
    pageFormat: pageFormat ?? this.pageFormat,
    buildBackground: buildBackground ?? this.buildBackground,
    buildForeground: buildForeground ?? this.buildForeground,
    theme: theme ?? this.theme,
    orientation: orientation ?? this.orientation,
    // The raw field, not the margin getter: the getter is where rotation and
    // falling back to the page format's own margins happen, so feeding it back
    // in rotated the edges one more quarter turn on every call and froze an
    // implicit margin into an explicit one.
    margin: margin ?? _margin,
    clip: clip ?? this.clip,
    textDirection: textDirection ?? this.textDirection,
  );
}
