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

    print("box ${box.bottom}");
    print("box ${box.top}");
    var left = box.left + maxTextWidth + xMargin;
    var top = box.top - textHeight / 2;
    var right = box.right - maxTextWidth / 2;
    var bottom = box.bottom + textHeight + yMargin;

    context.canvas
      ..setColor(PdfColors.black)
      ..drawString(
        style.font.getFont(context),
        style.fontSize,
        xAxis.first.toString(),
        maxTextWidth / 2 -
            (font.stringMetrics(xAxis.first.toString()) * (style.fontSize))
                    .width /
                2,
        0,
      );

    for (double x in xAxis.where((double x) => x != xAxis.first)) {
      var textWidth =
          (font.stringMetrics(x.toString()) * (style.fontSize)).width;
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          x.toString(),
          left + (right - left) * x / xAxis.last - textWidth / 2,
          0,
        );
    }

    for (double y in yAxis.where((double y) => y != yAxis.first)) {
      var textWidth =
          (font.stringMetrics(y.toString()) * (style.fontSize)).width;
      var yPos = bottom + (top - bottom) * y / yAxis.last;
      context.canvas
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          y.toString(),
          maxTextWidth / 2 - textWidth / 2,
          yPos - font.ascent,
        );

      context.canvas
        ..setStrokeColor(PdfColors.grey)
        ..setLineWidth(1.0)
        ..drawLine(left, yPos + font.descent + font.ascent - 0.5, right,
            yPos + font.descent + font.ascent - 0.5)
        ..strokePath();
    }

    super.paintRect(
        context,
        PdfRect.fromLTRB(
            left, bottom, right, top + font.descent + font.ascent + 1));
  }
}

class ScatterChart extends Widget {
  ScatterChart(
      {this.data,
      this.width = 200,
      this.height = 100,
      this.fit = BoxFit.contain,
      int xAxisIntersect = 5,
      this.yAxis,
      this.xAxisMargin = 10,
      this.yAxisMargin = 2,
        this.pointSize = 3,
        this.pointColor = PdfColors.red,
      this.gridTextStyle}) {
    yAxis = List<double>.generate(
        xAxisIntersect + 1,
        (int i) =>
            i / xAxisIntersect.toDouble() * data.reduce(math.max).ceil());
    xAxis ??= List<double>.generate(data.length + 1, (int i) => i.toDouble());

    maxValue = data.reduce(math.max);

    axes = Axes(
        xAxis: xAxis,
        yAxis: yAxis,
        xMargin: xAxisMargin,
        yMargin: yAxisMargin,
        textStyle: gridTextStyle,
        maxValue: maxValue);
  }

  final double width;
  final double height;
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
        (font.stringMetrics(maxValue.toString()) * (style.fontSize)).width;
    final textHeight = (font.stringMetrics(' ') * (style.fontSize)).height;

    box = PdfRect(0, 0, box.width, box.height);
    axes.paint(
      context,
      box,
      style,
      maxTextWidth,
      textHeight,
    );

    var left = box.left + maxTextWidth + xAxisMargin;
    var top = box.top - textHeight / 2;
    var right = box.right - maxTextWidth / 2;
    var bottom = box.bottom + textHeight + yAxisMargin;

    var lastPoint = 0.0;
    data.asMap().forEach((int i, double point) {
      context.canvas
        ..setStrokeColor(PdfColors.red)
        ..setLineWidth(2.0)
        ..drawLine(
            left + (right - left) * i / xAxis.last - pointSize / 2,
            bottom + (top - bottom) * lastPoint / maxValue,
            left + (right - left) * (i + 1) / xAxis.last - pointSize / 2,
            bottom + (top - bottom) * point / maxValue)
        ..strokePath();

      context.canvas
        ..setColor(pointColor)
        ..drawEllipse(
            left + (right - left) * (i + 1) / xAxis.last - pointSize / 2,
            bottom + (top - bottom) * point / maxValue,
            pointSize,
            pointSize)
        ..fillPath();

      lastPoint = point;
    });

    context.canvas.restoreContext();
  }
}
