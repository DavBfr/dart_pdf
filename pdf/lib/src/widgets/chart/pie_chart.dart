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

enum PieLegendPosition { none, auto, inside }

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
    this.legendPosition = PieLegendPosition.auto,
  })  : drawBorder = drawBorder ?? borderColor != null && color != borderColor,
        assert((drawBorder ?? borderColor != null && color != borderColor) ||
            drawSurface),
        super(
          legend: legend,
          color: color,
        );

  final double value;

  late double angleStart;

  late double angleEnd;

  final bool drawBorder;
  final PdfColor? borderColor;
  final double borderWidth;

  final bool drawSurface;

  final double surfaceOpacity;

  final double offset;

  final TextStyle? legendStyle;

  final PieLegendPosition legendPosition;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    // final size = constraints.biggest;

    // ignore: avoid_as
    final grid = Chart.of(context).grid as PieGrid;
    final len = grid.pieSize + offset;

    box = PdfRect(-len, -len, len * 2, len * 2);
  }

  void _shape(Context context) {
    // ignore: avoid_as
    final grid = Chart.of(context).grid as PieGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final sx = cx + sin(angleStart) * grid.pieSize;
    final sy = cy + cos(angleStart) * grid.pieSize;
    final ex = cx + sin(angleEnd) * grid.pieSize;
    final ey = cy + cos(angleEnd) * grid.pieSize;

    context.canvas
      ..moveTo(cx, cy)
      ..lineTo(sx, sy)
      ..bezierArc(sx, sy, grid.pieSize, grid.pieSize, ex, ey,
          large: angleEnd - angleStart > pi);
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
    if (legendPosition != PieLegendPosition.none && legend != null) {
      // ignore: avoid_as
      final grid = Chart.of(context).grid as PieGrid;

      final bisect = (angleStart + angleEnd) / 2;

      final o = grid.pieSize * 2 / 3;
      final cx = sin(bisect) * (offset + o);
      final cy = cos(bisect) * (offset + o);

      Widget.draw(
        Text(legend!, style: legendStyle, textAlign: TextAlign.center),
        offset: PdfPoint(cx, cy),
        context: context,
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
      );
    }
  }
}
