part of widget;

class Axes extends BoxBorder {
  Axes({
    this.xAxis,
    this.yAxis,
    this.xMargin,
    this.yMargin,
    this.textStyle,
    this.maxValue,
  }) : super(left: true, bottom: true);

  final List<double> xAxis;
  final List<double> yAxis;
  final int xMargin;
  final int yMargin;
  final double maxValue;

  TextStyle textStyle;

  void paint(Context context, PdfRect box, TextStyle style, double maxTextWidth,
      double textHeight) {
    final font = style.font.getFont(context);

    var gridLeft = box.left + maxTextWidth + xMargin;
    var gridTop = box.top - textHeight / 2;
    var gridRight = box.right - maxTextWidth / 2;
    var gridBottom = box.bottom + textHeight + yMargin;

    xAxis.asMap().forEach((int i, double x) {
      var textWidth =
          (font.stringMetrics(x.toStringAsFixed(1)) * (style.fontSize)).width;
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          x.toStringAsFixed(1),
          gridLeft +
              (gridRight - gridLeft) * i / (xAxis.length - 1) -
              textWidth / 2,
          0,
        );
    });

    for (double y in yAxis.where((double y) => y != yAxis.first)) {
      var textWidth =
          (font.stringMetrics(y.toStringAsFixed(1)) * (style.fontSize)).width;
      var yPos = gridBottom + (gridTop - gridBottom) * y / yAxis.last;
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          y.toStringAsFixed(1),
          maxTextWidth / 2 - textWidth / 2,
          yPos - font.ascent,
        );

      context.canvas
        ..setStrokeColor(PdfColors.grey)
        ..setLineWidth(1.0)
        ..drawLine(gridLeft, yPos + font.descent + font.ascent - 0.5, gridRight,
            yPos + font.descent + font.ascent - 0.5)
        ..strokePath();
    }

    super.paintRect(
        context,
        PdfRect.fromLTRB(gridLeft, gridBottom, gridRight,
            gridTop + font.descent + font.ascent + 1));
  }
}

class ScatterChart extends Widget {
  ScatterChart(
      {@required this.data,
      this.width = 500,
      this.height = 250,
      this.fit = BoxFit.contain,
      int yNrSeparators = 5,
      this.xAxis,
      this.yAxis,
      this.xAxisMargin = 10,
      this.yAxisMargin = 2,
      this.pointSize = 3,
      this.pointColor = PdfColors.red,
      this.drawLine = true,
      this.drawPoints = true,
      this.lineStartingPoint,
      this.pointLineWidth = 2.0,
      this.pointLineColor = PdfColors.red,
      this.gridTextStyle}) {
    yAxis ??= List<double>.generate(yNrSeparators + 1,
        (int i) => i / yNrSeparators.toDouble() * data.reduce(math.max).ceil());
    xAxis ??= List<double>.generate(data.length + 1, (int i) => i.toDouble());

    maxValue = yAxis.reduce(math.max);

    assert(maxValue >= data.reduce(math.max));
    assert(xAxis.length > data.length);
    assert(drawLine || drawPoints);

    axes = Axes(
        xAxis: xAxis,
        yAxis: yAxis,
        xMargin: xAxisMargin,
        yMargin: yAxisMargin,
        textStyle: gridTextStyle,
        maxValue: maxValue);
  }

  final double height;
  final double width;
  final BoxFit fit;
  final List<double> data;
  double maxTextWidth;
  double textHeight;
  double maxValue;
  List<double> xAxis;
  List<double> yAxis;
  int xAxisMargin;
  int yAxisMargin;
  double pointSize;
  PdfColor pointColor;
  bool drawLine;
  bool drawPoints;
  double lineStartingPoint;
  double pointLineWidth;
  PdfColor pointLineColor;

  final TextStyle gridTextStyle;
  Axes axes;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(width.toDouble());
    final h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(height.toDouble());

    final sizes = applyBoxFit(fit, PdfPoint(width, height), PdfPoint(w, h));
    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    final style = gridTextStyle ?? Theme.of(context).defaultTextStyle;
    final font = style.font.getFont(context);

    final maxTextWidth =
        (font.stringMetrics(maxValue.toStringAsFixed(1)) * (style.fontSize))
            .width;
    final textHeight = (font.stringMetrics(' ') * (style.fontSize)).height;

    box = PdfRect(0, 0, box.width, box.height);

    axes.paint(
      context,
      box,
      style,
      maxTextWidth,
      textHeight,
    );

    var gridLeft = box.left + maxTextWidth + xAxisMargin;
    var gridTop = box.top - textHeight / 2;
    var gridRight = box.right - maxTextWidth / 2;
    var gridBottom = box.bottom + textHeight + yAxisMargin;

    if (drawLine) {
      var lastPoint = lineStartingPoint;
      data.asMap().forEach((int i, double point) {
        if (lastPoint != null) {
          context.canvas.drawLine(
              gridLeft + (gridRight - gridLeft) * i / (xAxis.length - 1),
              gridBottom + (gridTop - gridBottom) * lastPoint / maxValue,
              gridLeft + (gridRight - gridLeft) * (i + 1) / (xAxis.length - 1),
              gridBottom + (gridTop - gridBottom) * point / maxValue);
          lastPoint = point;
        }
      });

      context.canvas
        ..setStrokeColor(pointLineColor)
        ..setLineWidth(pointLineWidth)
        ..setLineCap(PdfLineCap.joinRound)
        ..setLineJoin(PdfLineCap.joinRound)
        ..strokePath();
    }

    if (drawPoints) {
      data.asMap().forEach((int i, double point) {
        context.canvas
          ..setColor(pointColor)
          ..drawEllipse(
              gridLeft + (gridRight - gridLeft) * (i + 1) / (xAxis.length - 1),
              gridBottom + (gridTop - gridBottom) * point / maxValue,
              pointSize,
              pointSize)
          ..fillPath();
      });
    }

    context.canvas.restoreContext();
  }
}
