/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

import 'package:meta/meta.dart';

import 'document.dart';
import 'format/dict.dart';
import 'format/name.dart';
import 'format/num.dart';
import 'obj/function.dart';
import 'obj/object.dart';
import 'obj/smask.dart';

enum PdfBlendMode {
  /// Selects the source color, ignoring the backdrop
  normal,

  /// Multiplies the backdrop and source color values
  multiply,

  /// Multiplies the complements of the backdrop and source color values,
  /// then complements the result
  screen,

  /// Multiplies or screens the colors, depending on the backdrop color value
  overlay,

  /// Selects the darker of the backdrop and source colors
  darken,

  /// Selects the lighter of the backdrop and source colors
  lighten,

  /// Brightens the backdrop color to reflect the source color.
  /// Painting with black produces no changes.
  colorDodge,

  /// Darkens the backdrop color to reflect the source color
  colorBurn,

  /// Multiplies or screens the colors, depending on the source color value
  hardLight,

  /// Darkens or lightens the colors, depending on the source color value
  softLight,

  /// Subtracts the darker of the two constituent colors from the lighter color
  difference,

  /// Produces an effect similar to that of the Difference mode but lower in contrast
  exclusion,

  /// Creates a color with the hue of the source color and the saturation and
  /// luminosity of the backdrop color
  hue,

  /// Creates a color with the saturation of the source color and the hue and
  /// luminosity of the backdrop color
  saturation,

  /// Creates a color with the hue and saturation of the source color and the
  /// luminosity of the backdrop color
  color,

  /// Creates a color with the luminosity of the source color and the hue and
  /// saturation of the backdrop color
  luminosity,
}

/// Graphic state
@immutable
class PdfGraphicState {
  /// Create a new graphic state
  const PdfGraphicState({
    double? opacity,
    double? strokeOpacity,
    double? fillOpacity,
    this.blendMode,
    this.softMask,
    this.transferFunction,
  })  : fillOpacity = fillOpacity ?? opacity,
        strokeOpacity = strokeOpacity ?? opacity;

  /// Fill opacity to apply to this graphic state
  final double? fillOpacity;

  /// Stroke opacity to apply to this graphic state
  final double? strokeOpacity;

  /// The current blend mode to be used
  final PdfBlendMode? blendMode;

  /// Opacity mask
  final PdfSoftMask? softMask;

  /// Color transfer function
  final PdfFunction? transferFunction;

  @override
  String toString() =>
      '$runtimeType fillOpacity:$fillOpacity strokeOpacity:$strokeOpacity blendMode:$blendMode softMask:$softMask transferFunction:$transferFunction';

  PdfDict output() {
    final params = PdfDict();

    if (strokeOpacity != null) {
      params['/CA'] = PdfNum(strokeOpacity!);
    }

    if (fillOpacity != null) {
      params['/ca'] = PdfNum(fillOpacity!);
    }

    if (blendMode != null) {
      final bm = blendMode.toString();
      params['/BM'] =
          PdfName('/${bm.substring(13, 14).toUpperCase()}${bm.substring(14)}');
    }

    if (softMask != null) {
      params['/SMask'] = softMask!.output();
    }

    if (transferFunction != null) {
      params['/TR'] = transferFunction!.ref();
    }

    return params;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! PdfGraphicState) {
      return false;
    }
    return other.fillOpacity == fillOpacity &&
        other.strokeOpacity == strokeOpacity &&
        other.blendMode == blendMode &&
        other.softMask == softMask &&
        other.transferFunction == transferFunction;
  }

  @override
  int get hashCode =>
      fillOpacity.hashCode *
      strokeOpacity.hashCode *
      blendMode.hashCode *
      softMask.hashCode *
      transferFunction.hashCode;
}

/// Stores all the graphic states used in the document
class PdfGraphicStates extends PdfObject<PdfDict> {
  /// Create a new Graphic States object
  PdfGraphicStates(PdfDocument pdfDocument)
      : super(pdfDocument, params: PdfDict());

  final List<PdfGraphicState> _states = <PdfGraphicState>[];

  static const String _prefix = '/a';

  /// Generate a name for a state object
  String stateName(PdfGraphicState state) {
    var index = _states.indexOf(state);
    if (index < 0) {
      index = _states.length;
      _states.add(state);
    }
    return '$_prefix$index';
  }

  @override
  void prepare() {
    super.prepare();

    for (var index = 0; index < _states.length; index++) {
      params['$_prefix$index'] = _states[index].output();
    }
  }
}
