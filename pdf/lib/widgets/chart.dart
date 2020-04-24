part of widget;

// ignore_for_file: omit_local_variable_types

class Chart extends Widget {
  Chart({
    @required this.grid,
    @required this.data,
    this.width = 500,
    this.height = 250,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final BoxFit fit;
  final Grid grid;
  final List<DataSet> data;
  PdfRect gridBox;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final double w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(width.toDouble());
    final double h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(height.toDouble());

    final FittedSizes sizes =
        applyBoxFit(fit, PdfPoint(width, height), PdfPoint(w, h));

    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
    grid.layout(context, box);
    for (DataSet dataSet in data) {
      dataSet.layout(context, grid.gridBox);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    grid.paint(context, box);
    for (DataSet dataSet in data) {
      dataSet.paint(context, grid.gridBox);
    }
    context.canvas.restoreContext();
  }
}

abstract class Grid {
  PdfRect gridBox;

  void layout(Context context, PdfRect box);
  void paint(Context context, PdfRect box);
}

class LinearGrid extends Grid {
  LinearGrid({
    @required this.xAxis,
    @required this.yAxis,
    this.xMargin = 10,
    this.yMargin = 2,
    this.textStyle,
    this.lineWidth = 1,
    this.color = PdfColors.black,
    this.separatorLineWidth = 1,
    this.separatorColor = PdfColors.grey,
  });

  final List<double> xAxis;
  final List<double> yAxis;
  final double xMargin;
  final double yMargin;
  final TextStyle textStyle;
  final double lineWidth;
  final PdfColor color;

  TextStyle style;
  PdfFont font;
  PdfFontMetrics xAxisFontMetric;
  PdfFontMetrics yAxisFontMetric;
  double separatorLineWidth;
  PdfColor separatorColor;

  @override
  void layout(Context context, PdfRect box) {
    style = textStyle ?? Theme.of(context).defaultTextStyle;
    font = style.font.getFont(context);

    xAxisFontMetric =
        font.stringMetrics(xAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);
    yAxisFontMetric =
        font.stringMetrics(yAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);

    gridBox = PdfRect.fromLTRB(
        box.left + yAxisFontMetric.width + xMargin,
        box.bottom + xAxisFontMetric.height + yMargin,
        box.right - xAxisFontMetric.width / 2,
        box.top - yAxisFontMetric.height / 2);
  }

  @override
  void paint(Context context, PdfRect box) {
    xAxis.asMap().forEach((int i, double x) {
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          x.toStringAsFixed(1),
          gridBox.left +
              gridBox.width * i / (xAxis.length - 1) -
              xAxisFontMetric.width / 2,
          0,
        );
    });

    for (double y in yAxis.where((double y) => y != yAxis.first)) {
      final double textWidth =
          (font.stringMetrics(y.toStringAsFixed(1)) * (style.fontSize)).width;
      final double yPos = gridBox.bottom + gridBox.height * y / yAxis.last;
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          y.toStringAsFixed(1),
          xAxisFontMetric.width / 2 - textWidth / 2,
          yPos - font.ascent,
        );

      context.canvas.drawLine(
          gridBox.left,
          yPos + font.descent + font.ascent - separatorLineWidth / 2,
          gridBox.right,
          yPos + font.descent + font.ascent - separatorLineWidth / 2);
    }
    context.canvas
      ..setStrokeColor(separatorColor)
      ..setLineWidth(separatorLineWidth)
      ..strokePath();

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(lineWidth)
      ..drawLine(gridBox.left, gridBox.bottom, gridBox.right, gridBox.bottom)
      ..drawLine(gridBox.left, gridBox.bottom, gridBox.left, gridBox.top)
      ..strokePath();
  }
}

abstract class DataSet {
  void layout(Context context, PdfRect box);
  void paint(Context context, PdfRect box);
}

class LineDataSet extends DataSet {
  LineDataSet({
    @required this.data,
    this.pointColor = PdfColors.green,
    this.pointSize = 8,
    this.lineColor = PdfColors.blue,
    this.lineWidth = 2,
    this.drawLine = true,
    this.drawPoints = true,
    this.lineStartingPoint,
  }) : assert(drawLine || drawPoints);

  final List<double> data;
  final PdfColor pointColor;
  final double pointSize;
  final PdfColor lineColor;
  final double lineWidth;
  final bool drawLine;
  final bool drawPoints;
  final double lineStartingPoint;

  double maxValue;

  @override
  void layout(Context context, PdfRect box) {
    maxValue = data.reduce(math.max);
  }

  @override
  void paint(Context context, PdfRect box) {
    if (drawLine) {
      double lastPoint = lineStartingPoint;
      data.asMap().forEach((int i, double point) {
        if (lastPoint != null) {
          context.canvas.drawLine(
              box.left + box.width * i / data.length,
              box.bottom + box.height * lastPoint / maxValue,
              box.left + box.width * (i + 1) / data.length,
              box.bottom + box.height * point / maxValue);
          lastPoint = point;
        }
      });

      context.canvas
        ..setStrokeColor(lineColor)
        ..setLineWidth(lineWidth)
        ..setLineCap(PdfLineCap.joinRound)
        ..setLineJoin(PdfLineCap.joinRound)
        ..strokePath();
    }

    if (drawPoints) {
      data.asMap().forEach((int i, double point) {
        context.canvas
          ..setColor(pointColor)
          ..drawEllipse(box.left + box.width * (i + 1) / data.length,
              box.bottom + box.height * point / maxValue, pointSize, pointSize)
          ..fillPath();
      });
    }
  }
}