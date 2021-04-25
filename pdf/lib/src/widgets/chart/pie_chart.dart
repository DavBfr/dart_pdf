// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

class PieGrid extends ChartGrid {
  PieGrid({this.startAngle = 0});

  /// Start angle for the first [PieDataSet]
  final double startAngle;

  late double _radius;

  /// Nominal radius of a pie slice
  double get radius => _radius;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);

    final datasets = Chart.of(context).datasets;
    final size = constraints.biggest;

    final _gridBox = PdfRect(0, 0, size.x, size.y);

    var _total = 0.0;

    for (final dataset in datasets) {
      assert(dataset is PieDataSet, 'Use only PieDataset with a PieGrid');
      if (dataset is PieDataSet) {
        _total += dataset.value;
      }
    }

    final unit = pi / _total * 2;
    var angle = startAngle;

    for (final dataset in datasets) {
      if (dataset is PieDataSet) {
        dataset.angleStart = angle;
        angle += dataset.value * unit;
        dataset.angleEnd = angle;
      }
    }

    _radius = min(_gridBox.width / 2, _gridBox.height / 2);
    var reduce = false;

    do {
      reduce = false;
      for (final dataset in datasets) {
        if (dataset is PieDataSet) {
          dataset.layout(context, BoxConstraints.tight(_gridBox.size));
          assert(dataset.box != null);
          if (_radius > 20 &&
              (dataset.box!.width > _gridBox.width ||
                  dataset.box!.height > _gridBox.height)) {
            _radius -= 10;
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
    PdfColor? legendLineColor,
    Widget? legendWidget,
    this.legendOffset = 20,
    this.innerRadius = 0,
  })  : assert(innerRadius >= 0),
        assert(offset >= 0),
        drawBorder = drawBorder ?? borderColor != null && color != borderColor,
        assert((drawBorder ?? borderColor != null && color != borderColor) ||
            drawSurface),
        _legendWidget = legendWidget,
        legendLineColor = legendLineColor ?? color,
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

  final double innerRadius;

  PdfPoint? _legendAnchor;
  PdfPoint? _legendPivot;
  PdfPoint? _legendStart;

  bool get _isFullCircle => angleEnd - angleStart >= pi * 2;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final _offset = _isFullCircle ? 0 : offset;

    final grid = Chart.of(context).grid as PieGrid;
    final len = grid.radius + _offset;
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
        : RichText(
            text: TextSpan(
              children: [TextSpan(text: legend!, style: legendStyle)],
              style: TextStyle(
                  color: lp == PieLegendPosition.inside
                      ? color!.isLight
                          ? PdfColors.white
                          : PdfColors.black
                      : null),
            ),
            textAlign: _legendAlign,
          );

    if (_legendWidget != null) {
      _legendWidget!.layout(context,
          BoxConstraints(maxWidth: grid.radius, maxHeight: grid.radius));
      assert(_legendWidget!.box != null);

      final ls = _legendWidget!.box!.size;

      // final style = Theme.of(context).defaultTextStyle.merge(legendStyle);

      switch (lp) {
        case PieLegendPosition.outside:
          final o = grid.radius + legendOffset;
          final cx = sin(bisect) * (_offset + o);
          final cy = cos(bisect) * (_offset + o);

          _legendStart = PdfPoint(
            sin(bisect) * (_offset + grid.radius + legendOffset * 0.1),
            cos(bisect) * (_offset + grid.radius + legendOffset * 0.1),
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
          final double o;
          final double cx;
          final double cy;
          if (innerRadius == 0) {
            o = _isFullCircle ? 0 : grid.radius * 2 / 3;
            cx = sin(bisect) * (_offset + o);
            cy = cos(bisect) * (_offset + o);
          } else {
            o = (grid.radius + innerRadius) / 2;
            if (_isFullCircle) {
              cx = 0;
              cy = o;
            } else {
              cx = sin(bisect) * (_offset + o);
              cy = cos(bisect) * (_offset + o);
            }
          }
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

  void _paintSliceShape(Context context) {
    final grid = Chart.of(context).grid as PieGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final sx = cx + sin(angleStart) * grid.radius;
    final sy = cy + cos(angleStart) * grid.radius;
    final ex = cx + sin(angleEnd) * grid.radius;
    final ey = cy + cos(angleEnd) * grid.radius;

    if (_isFullCircle) {
      context.canvas.drawEllipse(0, 0, grid.radius, grid.radius);
    } else {
      context.canvas
        ..moveTo(cx, cy)
        ..lineTo(sx, sy)
        ..bezierArc(sx, sy, grid.radius, grid.radius, ex, ey,
            large: angleEnd - angleStart > pi);
    }
  }

  void _paintDonnutShape(Context context) {
    final grid = Chart.of(context).grid as PieGrid;

    final bisect = (angleStart + angleEnd) / 2;

    final cx = sin(bisect) * offset;
    final cy = cos(bisect) * offset;

    final stx = cx + sin(angleStart) * grid.radius;
    final sty = cy + cos(angleStart) * grid.radius;
    final etx = cx + sin(angleEnd) * grid.radius;
    final ety = cy + cos(angleEnd) * grid.radius;
    final sbx = cx + sin(angleStart) * innerRadius;
    final sby = cy + cos(angleStart) * innerRadius;
    final ebx = cx + sin(angleEnd) * innerRadius;
    final eby = cy + cos(angleEnd) * innerRadius;

    if (_isFullCircle) {
      context.canvas.drawEllipse(0, 0, grid.radius, grid.radius);
      context.canvas
          .drawEllipse(0, 0, innerRadius, innerRadius, clockwise: false);
    } else {
      context.canvas
        ..moveTo(stx, sty)
        ..bezierArc(stx, sty, grid.radius, grid.radius, etx, ety,
            large: angleEnd - angleStart > pi)
        ..lineTo(ebx, eby)
        ..bezierArc(ebx, eby, innerRadius, innerRadius, sbx, sby,
            large: angleEnd - angleStart > pi, sweep: true)
        ..lineTo(stx, sty);
    }
  }

  void _paintShape(Context context) {
    if (innerRadius == 0) {
      _paintSliceShape(context);
    } else {
      _paintDonnutShape(context);
    }
  }

  @override
  void paintBackground(Context context) {
    super.paint(context);

    if (drawSurface) {
      _paintShape(context);
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
      _paintShape(context);
      context.canvas
        ..setLineWidth(borderWidth)
        ..setLineJoin(PdfLineJoin.round)
        ..setStrokeColor(borderColor ?? color)
        ..strokePath(close: true);
    }
  }

  @protected
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

    final cx = sin(bisect) * (offset + grid.radius + legendOffset);
    final cy = cos(bisect) * (offset + grid.radius + legendOffset);

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
