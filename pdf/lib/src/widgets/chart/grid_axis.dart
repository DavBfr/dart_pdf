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

import 'package:pdf/pdf.dart';

import '../basic.dart';
import '../flex.dart';
import '../geometry.dart';
import '../text.dart';
import '../text_style.dart';
import '../widget.dart';
import 'chart.dart';
import 'grid_cartesian.dart';

typedef GridAxisFormat = String Function(num value);
typedef GridAxisBuildLabel = Widget Function(num value);

abstract class GridAxis extends Widget {
  GridAxis({
    GridAxisFormat format,
    this.textStyle,
    this.margin,
    double marginStart,
    double marginEnd,
    PdfColor color,
    double width,
    bool divisions,
    double divisionsWidth,
    PdfColor divisionsColor,
    bool divisionsDashed,
    bool ticks,
    bool axisTick,
    this.angle = 0,
    this.buildLabel,
  })  : format = format ?? _defaultFormat,
        color = color ?? PdfColors.black,
        width = width ?? 1,
        divisions = divisions ?? false,
        divisionsWidth = divisionsWidth ?? .5,
        divisionsColor = divisionsColor ?? PdfColors.grey,
        _marginStart = marginStart ?? 0,
        _marginEnd = marginEnd ?? 0,
        ticks = ticks ?? false,
        _axisTick = axisTick,
        divisionsDashed = divisionsDashed ?? false;

  Axis direction;

  final GridAxisFormat format;

  final GridAxisBuildLabel buildLabel;

  final TextStyle textStyle;

  final double margin;

  double crossAxisPosition = 0;

  double _textMargin;

  final double _marginStart;

  double _marginEnd;

  final PdfColor color;

  final double width;

  final bool divisions;

  final double divisionsWidth;

  final PdfColor divisionsColor;

  final bool divisionsDashed;

  final bool ticks;

  bool _axisTick;

  double axisPosition = 0;

  final double angle;

  static String _defaultFormat(num v) => v.toString();

  double transfer(num input) {
    return input.toDouble();
  }

  double toChart(num input);

  void paintBackground(Context context);
}

class FixedAxis<T extends num> extends GridAxis {
  FixedAxis(
    this.values, {
    GridAxisFormat format,
    TextStyle textStyle,
    double margin,
    double marginStart,
    double marginEnd,
    PdfColor color,
    double width,
    bool divisions,
    double divisionsWidth,
    PdfColor divisionsColor,
    bool divisionsDashed,
    bool ticks,
    bool axisTick,
    double angle = 0,
    GridAxisBuildLabel buildLabel,
  })  : assert(_isSortedAscending(values)),
        super(
          format: format,
          textStyle: textStyle,
          margin: margin,
          marginStart: marginStart,
          marginEnd: marginEnd,
          color: color,
          width: width,
          divisions: divisions,
          divisionsWidth: divisionsWidth,
          divisionsColor: divisionsColor,
          divisionsDashed: divisionsDashed,
          ticks: ticks,
          axisTick: axisTick,
          angle: angle,
          buildLabel: buildLabel,
        );

  static FixedAxis<int> fromStrings(
    List<String> values, {
    TextStyle textStyle,
    double margin,
    double marginStart,
    double marginEnd,
    PdfColor color,
    double width,
    bool divisions,
    double divisionsWidth,
    PdfColor divisionsColor,
    bool divisionsDashed,
    bool ticks,
    bool axisTick,
    double angle = 0,
    GridAxisBuildLabel buildLabel,
  }) {
    return FixedAxis<int>(
      List<int>.generate(values.length, (int index) => index),
      format: (num v) => values[v],
      textStyle: textStyle,
      margin: margin,
      marginStart: marginStart,
      marginEnd: marginEnd,
      color: color,
      width: width,
      divisions: divisions,
      divisionsWidth: divisionsWidth,
      divisionsColor: divisionsColor,
      divisionsDashed: divisionsDashed,
      ticks: ticks,
      axisTick: axisTick,
      angle: angle,
      buildLabel: buildLabel,
    );
  }

  final List<T> values;

  static bool _isSortedAscending(List<num> list) {
    var prev = list.first;
    for (final elem in list) {
      if (prev > elem) {
        return false;
      }
      prev = elem;
    }
    return true;
  }

  @override
  double toChart(num input) {
    final offset = transfer(values.first);
    final total = transfer(values.last) - offset;
    final start = crossAxisPosition + _marginStart;
    switch (direction) {
      case Axis.horizontal:
        return box.left +
            start +
            (box.width - start - _marginEnd) *
                (transfer(input) - offset) /
                total;
      case Axis.vertical:
        return box.bottom +
            start +
            (box.height - start - _marginEnd) *
                (transfer(input) - offset) /
                total;
    }

    return null;
  }

  Widget _text(num value) {
    final t = buildLabel == null
        ? Text(format(value), style: textStyle)
        : buildLabel(value);
    if (angle == 0.0) {
      return t;
    }

    return Transform.rotateBox(
      angle: angle,
      child: t,
    );
  }

  int _angleDirection() {
    if (angle == 0.0) {
      return 0;
    }
    if (angle % math.pi > math.pi / 2) {
      return -1;
    }
    return 1;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    assert(Chart.of(context) != null,
        '$runtimeType cannot be used without a Chart widget');

    final size = constraints.biggest;

    var maxWidth = 0.0;
    var maxHeight = 0.0;
    PdfPoint first;
    PdfPoint last;

    for (final value in values) {
      last = Widget.measure(_text(value), context: context);
      maxWidth = math.max(maxWidth, last.x);
      maxHeight = math.max(maxHeight, last.y);
      first ??= last;
    }

    final ad = _angleDirection();

    switch (direction) {
      case Axis.horizontal:
        _textMargin = margin ?? 2;
        _axisTick ??= false;
        final minStart = ad == 0 ? first.x / 2 : (ad > 0 ? first.x : 0.0);
        _marginEnd = math.max(
            _marginEnd, ad == 0 ? last.x / 2 : (ad > 0 ? 0.0 : last.x));
        crossAxisPosition = math.max(crossAxisPosition, minStart);
        axisPosition = math.max(axisPosition, maxHeight + _textMargin);
        box = PdfRect(0, 0, size.x, axisPosition);
        break;
      case Axis.vertical:
        _textMargin = margin ?? 10;
        _axisTick ??= true;
        _marginEnd = math.max(
            _marginEnd, ad == 0 ? last.x / 2 : (ad < 0 ? last.x : 0.0));
        final minStart = ad == 0 ? first.y / 2 : (ad > 0 ? first.x : 0.0);
        crossAxisPosition = math.max(crossAxisPosition, minStart);
        axisPosition = math.max(axisPosition, maxWidth + _textMargin);
        box = PdfRect(0, 0, axisPosition, size.y);
        break;
    }
  }

  void _drawYValues(Context context) {
    context.canvas
      ..moveTo(axisPosition, box.top)
      ..lineTo(axisPosition, box.bottom + crossAxisPosition);

    if (_axisTick && _textMargin > 0) {
      context.canvas
        ..moveTo(axisPosition, box.bottom + crossAxisPosition)
        ..lineTo(
            axisPosition - _textMargin / 2, box.bottom + crossAxisPosition);
    }

    if (ticks && _textMargin > 0) {
      for (final num x in values) {
        final p = toChart(x);
        context.canvas
          ..moveTo(axisPosition, p)
          ..lineTo(axisPosition - _textMargin / 2, p);
      }
    }

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..setLineJoin(PdfLineJoin.bevel)
      ..strokePath();

    final ad = _angleDirection();

    for (final y in values) {
      final p = toChart(y);

      Widget.draw(
        _text(y),
        offset: PdfPoint(axisPosition - _textMargin, p),
        context: context,
        alignment: ad == 0
            ? Alignment.centerRight
            : (ad > 0 ? Alignment.topRight : Alignment.bottomRight),
      );
    }
  }

  void _drawXValues(Context context) {
    context.canvas
      ..moveTo(box.left + crossAxisPosition, axisPosition)
      ..lineTo(box.right, axisPosition);

    if (_axisTick && _textMargin > 0) {
      context.canvas
        ..moveTo(box.left + crossAxisPosition, axisPosition)
        ..lineTo(box.left + crossAxisPosition, axisPosition - _textMargin);
    }

    if (ticks && _textMargin > 0) {
      for (final num x in values) {
        final p = toChart(x);
        context.canvas
          ..moveTo(p, axisPosition)
          ..lineTo(p, axisPosition - _textMargin);
      }
    }

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(width)
      ..setLineJoin(PdfLineJoin.bevel)
      ..strokePath();

    final ad = _angleDirection();

    for (final num x in values) {
      final p = toChart(x);

      Widget.draw(
        _text(x),
        offset: PdfPoint(p, axisPosition - _textMargin),
        context: context,
        alignment: ad == 0
            ? Alignment.topCenter
            : (ad > 0 ? Alignment.topRight : Alignment.topLeft),
      );
    }
  }

  @override
  void paintBackground(Context context) {
    if (!divisions) {
      return;
    }

    final CartesianGrid grid = Chart.of(context).grid;

    switch (direction) {
      case Axis.horizontal:
        for (final num x in values.sublist(_marginStart > 0 ? 0 : 1)) {
          final p = toChart(x);
          context.canvas.drawLine(p, grid.gridBox.top, p, grid.gridBox.bottom);
        }
        break;

      case Axis.vertical:
        for (final num y in values.sublist(_marginStart > 0 ? 0 : 1)) {
          final p = toChart(y);
          context.canvas.drawLine(grid.gridBox.left, p, grid.gridBox.right, p);
        }

        break;
    }

    if (divisionsDashed) {
      context.canvas.setLineDashPattern(<int>[4, 2]);
    }

    context.canvas
      ..setStrokeColor(divisionsColor)
      ..setLineWidth(divisionsWidth)
      ..setLineJoin(PdfLineJoin.miter)
      ..strokePath();

    if (divisionsDashed) {
      context.canvas.setLineDashPattern();
    }
  }

  @override
  void debugPaint(Context context) {
    switch (direction) {
      case Axis.horizontal:
        context.canvas
          ..setFillColor(PdfColors.grey300)
          ..drawBox(box)
          ..fillPath();
        break;
      case Axis.vertical:
        context.canvas
          ..setFillColor(PdfColors.grey300)
          ..drawRect(box.x, box.y + crossAxisPosition, box.width,
              box.height - crossAxisPosition)
          ..fillPath();
        break;
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    switch (direction) {
      case Axis.horizontal:
        _drawXValues(context);
        break;
      case Axis.vertical:
        _drawYValues(context);
        break;
    }
  }
}
