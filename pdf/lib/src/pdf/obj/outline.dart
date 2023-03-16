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

import '../color.dart';
import '../document.dart';
import '../format/array.dart';
import '../format/name.dart';
import '../format/num.dart';
import '../format/string.dart';
import '../rect.dart';
import 'object_dict.dart';
import 'page.dart';

/// Outline mode
enum PdfOutlineMode {
  /// When jumping to the destination, display the whole page
  fitPage,

  /// When jumping to the destination, display the specified region
  fitRect
}

/// Outline style
enum PdfOutlineStyle {
  /// Normal
  normal,

  /// Italic
  italic,

  /// Bold
  bold,

  /// Italic and Bold
  italicBold,
}

/// Pdf Outline object
class PdfOutline extends PdfObjectDict {
  /// Constructs a Pdf Outline object.
  /// When selected, the specified region is displayed.
  PdfOutline(
    PdfDocument pdfDocument, {
    this.title,
    this.dest,
    this.rect,
    this.anchor,
    this.color,
    this.destMode = PdfOutlineMode.fitPage,
    this.style = PdfOutlineStyle.normal,
    PdfPage? page,
  })  : assert(anchor == null || (dest == null && rect == null)),
        _page = page,
        super(pdfDocument);

  /// This holds any outlines below us
  List<PdfOutline> outlines = <PdfOutline>[];

  /// For subentries, this points to it's parent outline
  PdfOutline? parent;

  /// This is this outlines Title
  final String? title;

  /// The destination page
  PdfPage? dest;

  /// Page number
  String? get page {
    final int? num;
    if (_page != null) {
      num = pdfDocument.pdfPageList.pages.indexOf(_page!);
    } else if (dest != null) {
      num = pdfDocument.pdfPageList.pages.indexOf(dest!);
    } else {
      num = null;
    }

    return num == null ? null : (num + 1).toString();
  }

  final PdfPage? _page;

  /// The region on the destination page
  final PdfRect? rect;

  /// Named destination
  final String? anchor;

  /// Color of the outline text
  final PdfColor? color;

  /// How the destination is handled
  final PdfOutlineMode destMode;

  /// How to display the outline text
  final PdfOutlineStyle style;

  /// External level for this outline
  int? effectiveLevel;

  /// This method creates an outline, and attaches it to this one.
  /// When the outline is selected, the supplied region is displayed.
  void add(PdfOutline outline) {
    outline.parent = this;
    outlines.add(outline);
  }

  @override
  void prepare() {
    super.prepare();

    // These are for kids only
    if (parent != null) {
      params['/Title'] = PdfSecString.fromString(title!);

      if (color != null) {
        params['/C'] = PdfArray.fromColor(color!);
      }

      if (style != PdfOutlineStyle.normal) {
        params['/F'] = PdfNum(style.index);
      }

      if (anchor != null) {
        params['/Dest'] = PdfSecString.fromString(anchor!);
      } else {
        final dests = PdfArray();
        dests.add(dest!.ref());

        if (destMode == PdfOutlineMode.fitPage) {
          dests.add(const PdfName('/Fit'));
        } else {
          dests.add(const PdfName('/FitR'));
          dests.add(PdfNum(rect!.left));
          dests.add(PdfNum(rect!.bottom));
          dests.add(PdfNum(rect!.right));
          dests.add(PdfNum(rect!.top));
        }
        params['/Dest'] = dests;
      }
      params['/Parent'] = parent!.ref();

      // were a descendent, so by default we are closed. Find out how many
      // entries are below us
      final c = descendants();
      if (c > 0) {
        params['/Count'] = PdfNum(-c);
      }

      final index = parent!.getIndex(this);
      if (index > 0) {
        // Now if were not the first, then we have a /Prev node
        params['/Prev'] = parent!.getNode(index - 1).ref();
      }

      if (index < parent!.getLast()) {
        // We have a /Next node
        params['/Next'] = parent!.getNode(index + 1).ref();
      }
    } else {
      // the number of outlines in this document
      // were the top level node, so all are open by default
      params['/Count'] = PdfNum(outlines.length);
    }

    // These only valid if we have children
    if (outlines.isNotEmpty) {
      // the number of the first outline in list
      params['/First'] = outlines[0].ref();

      // the number of the last outline in list
      params['/Last'] = outlines[outlines.length - 1].ref();
    }
  }

  /// This is called by children to find their position in this outlines
  /// tree.
  int getIndex(PdfOutline outline) => outlines.indexOf(outline);

  /// Returns the last index in this outline
  int getLast() => outlines.length - 1;

  /// Returns the outline at a specified position.
  PdfOutline getNode(int i) => outlines[i];

  /// Returns the total number of descendants below this one.
  int descendants() {
    var c = outlines.length; // initially the number of kids

    // now call each one for their descendants
    for (final o in outlines) {
      c += o.descendants();
    }

    return c;
  }

  @override
  String toString() {
    return '$runtimeType $anchor $title';
  }
}
