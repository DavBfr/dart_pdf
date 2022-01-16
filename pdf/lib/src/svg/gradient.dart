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

import 'package:xml/xml.dart';

import '../../pdf.dart';
import 'color.dart';
import 'operation.dart';
import 'painter.dart';
import 'parser.dart';
import 'transform.dart';

enum GradientUnits {
  objectBoundingBox,
  userSpaceOnUse,
}

abstract class SvgGradient extends SvgColor {
  const SvgGradient(
    this.gradientUnits,
    this.transform,
    this.colors,
    this.stops,
    this.opacityList,
  )   : assert(colors.length == stops.length),
        assert(stops.length == opacityList.length),
        super();

  final GradientUnits? gradientUnits;

  final SvgTransform transform;

  final List<PdfColor?> colors;

  final List<double> stops;

  final List<double> opacityList;

  @override
  bool get isEmpty => colors.isEmpty;

  PdfPattern buildGradient(
      SvgOperation op, PdfGraphics canvas, List<PdfColor?> colors);

  @override
  void setFillColor(SvgOperation op, PdfGraphics canvas) {
    if (isEmpty) {
      return;
    }

    canvas.setFillPattern(buildGradient(op, canvas, colors));

    if (opacityList.any((o) => o < 1)) {
      final mask = PdfSoftMask(
        op.painter.document,
        boundingBox: op.painter.boundingBox,
      );
      canvas.setGraphicState(
        PdfGraphicState(
          softMask: mask,
        ),
      );
      final maskCanvas = mask.getGraphics()!;
      maskCanvas.drawBox(op.boundingBox());
      maskCanvas.setFillPattern(
        buildGradient(
          op,
          maskCanvas,
          opacityList.map<PdfColor>((o) => PdfColor(o, o, o)).toList(),
        ),
      );
      maskCanvas.fillPath();
      canvas.setFillPattern(buildGradient(op, canvas, colors));
    }
  }

  @override
  void setStrokeColor(SvgOperation op, PdfGraphics canvas) {
    if (isEmpty) {
      return;
    }

    canvas.setStrokePattern(buildGradient(op, canvas, colors));
  }
}

class SvgLinearGradient extends SvgGradient {
  const SvgLinearGradient(
      GradientUnits? gradientUnits,
      this.x1,
      this.y1,
      this.x2,
      this.y2,
      SvgTransform transform,
      List<PdfColor?> colors,
      List<double> stops,
      List<double> opacityList)
      : super(gradientUnits, transform, colors, stops, opacityList);

  factory SvgLinearGradient.fromXml(XmlElement element, SvgPainter painter) {
    final x1 = SvgParser.getNumeric(element, 'x1', null)?.sizeValue;
    final y1 = SvgParser.getNumeric(element, 'y1', null)?.sizeValue;
    final x2 = SvgParser.getNumeric(element, 'x2', null)?.sizeValue;
    final y2 = SvgParser.getNumeric(element, 'y2', null)?.sizeValue;

    final colors = <PdfColor?>[];
    final stops = <double>[];
    final opacityList = <double>[];

    for (final child in element.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'stop')) {
      SvgParser.convertStyle(child);
      final color = SvgColor.fromXml(
          child.getAttribute('stop-color') ?? 'black', painter);
      final opacity =
          SvgParser.getDouble(child, 'stop-opacity', defaultValue: 1)!;
      final stop = SvgParser.getNumeric(child, 'offset', null, defaultValue: 0)!
          .sizeValue;
      colors.add(color.color);
      stops.add(stop);
      opacityList.add(opacity);
    }

    GradientUnits? gradientUnits;
    switch (element.getAttribute('gradientUnits')) {
      case 'userSpaceOnUse':
        gradientUnits = GradientUnits.userSpaceOnUse;
        break;
      case 'objectBoundingBox':
        gradientUnits = GradientUnits.objectBoundingBox;
        break;
    }

    final result = SvgLinearGradient(
      gradientUnits,
      x1,
      y1,
      x2,
      y2,
      SvgTransform.fromString(element.getAttribute('gradientTransform')),
      colors,
      stops,
      opacityList,
    );

    SvgLinearGradient href;
    final hrefAttr = element.getAttribute('href') ??
        element.getAttribute('href', namespace: 'http://www.w3.org/1999/xlink');

    if (hrefAttr != null) {
      final hrefElement = painter.parser.findById(hrefAttr.substring(1));
      if (hrefElement != null) {
        href = SvgLinearGradient.fromXml(hrefElement, painter);
        return href.mergeWith(result);
      }
    }

    return result;
  }

  final double? x1;
  final double? y1;
  final double? x2;
  final double? y2;

  SvgLinearGradient mergeWith(SvgLinearGradient other) {
    return SvgLinearGradient(
      other.gradientUnits ?? gradientUnits,
      other.x1 ?? x1,
      other.y1 ?? y1,
      other.x2 ?? x2,
      other.y2 ?? y2,
      other.transform.isNotEmpty ? other.transform : transform,
      other.colors.isNotEmpty ? other.colors : colors,
      other.stops.isNotEmpty ? other.stops : stops,
      other.opacityList.isNotEmpty ? other.opacityList : opacityList,
    );
  }

  @override
  PdfPattern buildGradient(
      SvgOperation op, PdfGraphics canvas, List<PdfColor?> colors) {
    final mat = canvas.getTransform();

    if (gradientUnits != GradientUnits.userSpaceOnUse) {
      final bb = op.boundingBox();
      mat
        ..translate(bb.x, bb.y)
        ..scale(bb.width, bb.height);
    }

    if (transform.isNotEmpty) {
      mat.multiply(transform.matrix!);
    }

    return PdfShadingPattern(
      op.painter.document,
      shading: PdfShading(
        op.painter.document,
        shadingType: PdfShadingType.axial,
        function: PdfBaseFunction.colorsAndStops(
          op.painter.document,
          colors,
          stops,
        ),
        start: PdfPoint(x1 ?? 0, y1 ?? 0),
        end: PdfPoint(x2 ?? 1, y2 ?? 0),
        extendStart: true,
        extendEnd: true,
      ),
      matrix: mat,
    );
  }

  @override
  String toString() =>
      '$runtimeType userSpace:$gradientUnits x1:$x1 y1:$y1 x2:$x2 y2:$y2 colors:$colors stops:$stops opacityList:$opacityList';
}

class SvgRadialGradient extends SvgGradient {
  const SvgRadialGradient(
    GradientUnits? gradientUnits,
    this.r,
    this.cx,
    this.cy,
    this.fr,
    this.fx,
    this.fy,
    SvgTransform transform,
    List<PdfColor?> colors,
    List<double> stops,
    List<double> opacityList,
  ) : super(gradientUnits, transform, colors, stops, opacityList);

  factory SvgRadialGradient.fromXml(XmlElement element, SvgPainter painter) {
    final r =
        SvgParser.getNumeric(element, 'r', null, defaultValue: .5)!.sizeValue;
    final cx =
        SvgParser.getNumeric(element, 'cx', null, defaultValue: .5)!.sizeValue;
    final cy =
        SvgParser.getNumeric(element, 'cy', null, defaultValue: .5)!.sizeValue;
    final fr =
        SvgParser.getNumeric(element, 'fr', null, defaultValue: 0)!.sizeValue;
    final fx =
        SvgParser.getNumeric(element, 'fx', null, defaultValue: cx)!.sizeValue;
    final fy =
        SvgParser.getNumeric(element, 'fy', null, defaultValue: cy)!.sizeValue;

    final colors = <PdfColor?>[];
    final stops = <double>[];
    final opacityList = <double>[];

    for (final child in element.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'stop')) {
      SvgParser.convertStyle(child);
      final color = SvgColor.fromXml(
          child.getAttribute('stop-color') ?? 'black', painter);
      final opacity =
          SvgParser.getDouble(child, 'stop-opacity', defaultValue: 1);
      final stop = SvgParser.getNumeric(child, 'offset', null, defaultValue: 0)!
          .sizeValue;
      colors.add(color.color);
      stops.add(stop);
      opacityList.add(opacity!);
    }

    GradientUnits? gradientUnits;
    switch (element.getAttribute('gradientUnits')) {
      case 'userSpaceOnUse':
        gradientUnits = GradientUnits.userSpaceOnUse;
        break;
      case 'objectBoundingBox':
        gradientUnits = GradientUnits.objectBoundingBox;
        break;
    }

    final result = SvgRadialGradient(
        gradientUnits,
        r,
        cx,
        cy,
        fr,
        fx,
        fy,
        SvgTransform.fromString(element.getAttribute('gradientTransform')),
        colors,
        stops,
        opacityList);

    SvgRadialGradient href;
    final hrefAttr = element.getAttribute('href') ??
        element.getAttribute('href', namespace: 'http://www.w3.org/1999/xlink');

    if (hrefAttr != null) {
      final hrefElement = painter.parser.findById(hrefAttr.substring(1));
      if (hrefElement != null) {
        href = SvgRadialGradient.fromXml(hrefElement, painter);
        return href.mergeWith(result);
      }
    }

    return result;
  }

  final double? r;
  final double? cx;
  final double? cy;
  final double? fr;
  final double? fx;
  final double? fy;

  SvgRadialGradient mergeWith(SvgRadialGradient other) {
    return SvgRadialGradient(
      other.gradientUnits ?? gradientUnits,
      other.r ?? r,
      other.cx ?? cx,
      other.cy ?? cy,
      other.fr ?? fr,
      other.fx ?? fx,
      other.fy ?? fy,
      other.transform.isNotEmpty ? other.transform : transform,
      other.colors.isNotEmpty ? other.colors : colors,
      other.stops.isNotEmpty ? other.stops : stops,
      other.opacityList.isNotEmpty ? other.opacityList : opacityList,
    );
  }

  @override
  PdfPattern buildGradient(
      SvgOperation op, PdfGraphics canvas, List<PdfColor?> colors) {
    final mat = canvas.getTransform();

    if (gradientUnits != GradientUnits.userSpaceOnUse) {
      final bb = op.boundingBox();
      mat
        ..translate(bb.x, bb.y)
        ..scale(bb.width, bb.height);
    }

    if (transform.isNotEmpty) {
      mat.multiply(transform.matrix!);
    }

    return PdfShadingPattern(
      op.painter.document,
      shading: PdfShading(
        op.painter.document,
        shadingType: PdfShadingType.radial,
        function: PdfBaseFunction.colorsAndStops(
          op.painter.document,
          colors,
          stops,
        ),
        start: PdfPoint(fx ?? cx ?? .5, fy ?? cy ?? .5),
        end: PdfPoint(cx ?? .5, cy ?? .5),
        radius0: fr ?? 0,
        radius1: r ?? .5,
        extendStart: true,
        extendEnd: true,
      ),
      matrix: mat,
    );
  }

  @override
  String toString() =>
      '$runtimeType userSpace:$gradientUnits cx:$cx cy:$cy r:$r fx:$fx fy:$fy fr:$fr colors:$colors stops:$stops opacityList:$opacityList';
}
