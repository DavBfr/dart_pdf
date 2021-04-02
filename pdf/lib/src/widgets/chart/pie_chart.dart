// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

class PieGrid extends ChartGrid {
  PieGrid();

  late PdfRect gridBox;

  late double total;

  late double unit;

  late double pieSize;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);

    final datasets = Chart.of(context).datasets;
    final size = constraints.biggest;

    gridBox = PdfRect(0, 0, size.x, size.y);

    total = 0.0;

    for (final dataset in datasets) {
      assert(dataset is PieDataSet, 'Use only PieDataSet with a PieGrid');
      if (dataset is PieDataSet) {
        total += dataset.value;
      }
    }

    unit = pi / total * 2;
    var angle = 0.0;

    for (final dataset in datasets) {
      if (dataset is PieDataSet) {
        dataset.angleStart = angle;
        angle += dataset.value * unit;
        dataset.angleEnd = angle;
      }
    }

    pieSize = min(gridBox.width / 2, gridBox.height / 2);
    var reduce = false;

    do {
      reduce = false;
      for (final dataset in datasets) {
        if (dataset is PieDataSet) {
          dataset.layout(context, BoxConstraints.tight(gridBox.size));
          assert(dataset.box != null);
          if (pieSize > 20 &&
              (dataset.box!.width > gridBox.width ||
                  dataset.box!.height > gridBox.height)) {
            pieSize -= 10;
            reduce = true;
            break;
          }
        }
      }
    } while (reduce);
  }

  @override
  PdfPoint toChart(PdfPoint p) {
    return p;
  }

  void clip(Context context, PdfPoint size) {}

  @override
  void paint(Context context) {
    super.paint(context);

    final datasets = Chart.of(context).datasets;

    context.canvas
      ..saveContext()
      ..setTransform(
        Matrix4.translationValues(box!.width / 2, box!.height / 2, 0),
      );

    for (var dataSet in datasets) {
      if (dataSet is PieDataSet) {
        dataSet.paintBackground(context);
      }
    }

    for (var dataSet in datasets) {
      if (dataSet is PieDataSet) {
        dataSet.paint(context);
      }
    }

    for (var dataSet in datasets) {
      if (dataSet is PieDataSet) {
        dataSet.paintLegend(context);
      }
    }

    context.canvas.restoreContext();
  }
}

enum PieLegendPosition { none, auto, inside, outside }

class PieDataSet extends Dataset {
  PieDataSet({
    required this.value,
    String? legend,
    required PdfColor color,
    this.borderColor = PdfColors.white,
    this.borderWidth = 1.5,
    bool? drawBorder,
    this.drawSurface = true,
    this.surfaceOpacity = 1,
    this.offset = 0,
    this.legendStyle,
    this.legendAlign,
    this.legendPosition = PieLegendPosition.auto,
    this.legendLineWidth = 1.0,
    this.legendLineColor = PdfColors.black,
    Widget? legendWidget,
    this.legendOffset = 20,
  })  : drawBorder = drawBorder ?? borderColor != null && color != borderColor,
        assert((drawBorder ?? borderColor != null && color != borderColor) ||
            drawSurface),
        _legendWidget = legendWidget,
        super(
          legend: legend,
          color: color,
        );

  final num value;

  late double angleStart;

  late double angleEnd;

  final bool drawBorder;
  final PdfColor? borderColor;
  final double borderWidth;

  final bool drawSurface;

  final double surfaceOpacity;

  final double offset;

  final TextStyle? legendStyle;

  final TextAlign? legendAlign;
  final PieLegendPosition legendPosition;

  Widget? _legendWidget;

  final double legendOffset;

  final double legendLineWidth;

  final PdfColor legendLineColor;

  PdfPoint? _legendAnchor;
  PdfPoint? _legendPivot;
  PdfPoint? _legendStart;

  bool get _isFullCircle => angleEnd - angleStart >= pi * 2;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final _offset = _isFullCircle ? 0 : offset;

    final grid = Chart.of(context).grid as PieGrid;
    final len = grid.pieSize + _offset;
    var x = -len;
    var y = -len;
    var w = len * 2;
    var h = len * 2;

    final lp = legendPosition == PieLegendPosition.auto
        ? (angleEnd - angleStart > pi / 6
            ? PieLegendPosition.inside
            : PieLegendPosition.outside)
        : legendPosition;

    // Find the legend position
    final bisect = _isFullCircle ? 1 / 4 * pi : (angleStart + angleEnd) / 2;

    final _legendAlign = legendAlign ??
        (lp == PieLegendPosition.inside
            ? TextAlign.center
            : (bisect > pi ? TextAlign.right : TextAlign.left));

    _legendWidget ??= legend == null
        ? null
        : Text(legend!, style: legendStyle, textAlign: _legendAlign);

    if (_legendWidget != null) {
      _legendWidget!.layout(context,
          BoxConstraints(maxWidth: grid.pieSize, maxHeight: grid.pieSize));
      assert(_legendWidget!.box != null);

      final ls = _legendWidget!.box!.size;

      // final style = Theme.of(context).defaultTextStyle.merge(legendStyle);

      switch (lp) {
        case PieLegendPosition.outside:
          final o = grid.pieSize + legendOffset;
          final cx = sin(bisect) * (_offset + o);
          final cy = cos(bisect) * (_offset + o);

          _legendStart = PdfPoint(
            sin(bisect) * (_offset + grid.pieSize + legendOffset * 0.1),
            cos(bisect) * (_offset + grid.pieSize + legendOffset * 0.1),
          );

          _legendPivot = PdfPoint(cx, cy);
          if (bisect > pi) {
            _legendAnchor = PdfPoint(
              cx - legendOffset / 2 * 0.8,
              cy,
            );
            _legendWidget!.box = PdfRect.fromPoints(
                PdfPoint(
                  cx - legendOffset / 2 - ls.x,
                  cy - ls.y / 2,
                ),
                ls);
            w = max(w, (-cx + legendOffset / 2 + ls.x) * 2);
            h = max(h, cy.abs() * 2 + ls.y);
            x = -w / 2;
            y = -h / 2;
          } else {
            _legendAnchor = PdfPoint(
              cx + legendOffset / 2 * 0.8,
              cy,
            );
            _legendWidget!.box = PdfRect.fromPoints(
                PdfPoint(
                  cx + legendOffset / 2,
                  cy - ls.y / 2,
                ),
                ls);
            w = max(w, (cx + legendOffset / 2 + ls.x) * 2);
            h = max(h, cy.abs() * 2 + ls.y);
            x = -w / 2;
            y = -h / 2;
          }
          break;
        case PieLegendPosition.inside:
          final o = _isFullCircle ? 0 : grid.pieSize * 2 / 3;
          final cx = sin(bisect) * (_offset + o);
          final cy = cos(bisect) * (_offset + o);
          _legendWidget!.box = PdfRect.fromPoints(
              PdfPoint(
                cx - ls.x / 2,
                cy - ls.y / 2,
              ),
              ls);
          break;
        default:
          break;
      }
    }

    box = PdfRect(x, y, w, h);
  }

  void _shape(Context context) {
    final grid = Chart.of(context).grid as PieGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final sx = cx + sin(angleStart) * grid.pieSize;
    final sy = cy + cos(angleStart) * grid.pieSize;
    final ex = cx + sin(angleEnd) * grid.pieSize;
    final ey = cy + cos(angleEnd) * grid.pieSize;

    if (_isFullCircle) {
      context.canvas.drawEllipse(0, 0, grid.pieSize, grid.pieSize);
    } else {
      context.canvas
        ..moveTo(cx, cy)
        ..lineTo(sx, sy)
        ..bezierArc(sx, sy, grid.pieSize, grid.pieSize, ex, ey,
            large: angleEnd - angleStart > pi);
    }
  }

  @override
  void paintBackground(Context context) {
    super.paint(context);

    if (drawSurface) {
      _shape(context);
      if (surfaceOpacity != 1) {
        context.canvas
          ..saveContext()
          ..setGraphicState(
            PdfGraphicState(opacity: surfaceOpacity),
          );
      }

      context.canvas
        ..setFillColor(color)
        ..fillPath();

      if (surfaceOpacity != 1) {
        context.canvas.restoreContext();
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (drawBorder) {
      _shape(context);
      context.canvas
        ..setLineWidth(borderWidth)
        ..setLineJoin(PdfLineJoin.round)
        ..setStrokeColor(borderColor ?? color)
        ..strokePath(close: true);
    }
  }

  void paintLegend(Context context) {
    if (legendPosition != PieLegendPosition.none && _legendWidget != null) {
      if (_legendAnchor != null &&
          _legendPivot != null &&
          _legendStart != null) {
        context.canvas
          ..saveContext()
          ..moveTo(_legendStart!.x, _legendStart!.y)
          ..lineTo(_legendPivot!.x, _legendPivot!.y)
          ..lineTo(_legendAnchor!.x, _legendAnchor!.y)
          ..setLineWidth(legendLineWidth)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round)
          ..setStrokeColor(legendLineColor)
          ..strokePath()
          ..restoreContext();
      }

      _legendWidget!.paint(context);
    }
  }

  @override
  void debugPaint(Context context) {
    super.debugPaint(context);

    final grid = Chart.of(context).grid as PieGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * (offset + grid.pieSize + legendOffset);
    final cy = cos(bisect) * (offset + grid.pieSize + legendOffset);

    if (_legendWidget != null) {
      context.canvas
        ..saveContext()
        ..moveTo(0, 0)
        ..lineTo(cx, cy)
        ..setLineWidth(0.5)
        ..setLineDashPattern([3, 1])
        ..setStrokeColor(PdfColors.blue)
        ..strokePath()
        ..restoreContext();
    }
  }
}
