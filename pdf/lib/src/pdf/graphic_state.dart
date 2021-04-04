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

import 'data_types.dart';
import 'document.dart';
import 'function.dart';
import 'object_dict.dart';
import 'smask.dart';

enum PdfBlendMode {
  /// Selects the source colour, ignoring the backdrop
  normal,

  /// Multiplies the backdrop and source colour values
  multiply,

  /// Multiplies the complements of the backdrop and source colour values,
  /// then complements the result
  screen,

  /// Multiplies or screens the colours, depending on the backdrop colour value
  overlay,

  /// Selects the darker of the backdrop and source colours
  darken,

  /// Selects the lighter of the backdrop and source colours
  lighten,

  /// Brightens the backdrop colour to reflect the source colour.
  /// Painting with black produces no changes.
  colorDodge,

  /// Darkens the backdrop colour to reflect the source colour
  colorBurn,

  /// Multiplies or screens the colours, depending on the source colour value
  hardLight,

  /// Darkens or lightens the colours, depending on the source colour value
  softLight,

  /// Subtracts the darker of the two constituent colours from the lighter colour
  difference,

  /// Produces an effect similar to that of the Difference mode but lower in contrast
  exclusion,

  /// Creates a colour with the hue of the source colour and the saturation and
  /// luminosity of the backdrop colour
  hue,

  /// Creates a colour with the saturation of the source colour and the hue and
  /// luminosity of the backdrop colour
  saturation,

  /// Creates a colour with the hue and saturation of the source colour and the
  /// luminosity of the backdrop colour
  color,

  /// Creates a colour with the luminosity of the source colour and the hue and
  /// saturation of the backdrop colour
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
          PdfName('/' + bm.substring(13, 14).toUpperCase() + bm.substring(14));
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
    if (!(other is PdfGraphicState)) {
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
class PdfGraphicStates extends PdfObjectDict {
  /// Create a new Graphic States object
  PdfGraphicStates(PdfDocument pdfDocument) : super(pdfDocument);

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
