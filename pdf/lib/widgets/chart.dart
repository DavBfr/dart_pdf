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

  void paint(Context context, PdfRect box) {
    final style = textStyle ?? Theme.of(context).defaultTextStyle;
    final font = style.font.getFont(context);

//    final maxValue = data.reduce(
//            (max, y) => max.toString().length > y.toString().length ? max : y);
    final maxTextWidth =
        (font.stringMetrics(maxValue.toString()) * (style.fontSize)).width;
    final textHeight = (font.stringMetrics(' ') * (style.fontSize)).height;

//    var grid = PdfRect.fromLTRB(
     var left =    box.left + maxTextWidth + xMargin;
     var top =    box.top - textHeight / 2;
      var right =   box.right - maxTextWidth / 2;
      var bottom =   box.bottom + textHeight + yMargin;
//    );

//    var font = textStyle.font.getFont(context);

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
        ..drawLine(left, yPos + font.descent + font.ascent, right,
            yPos + font.descent + font.ascent)
        ..strokePath();
    }

//    super.paintRect(
//        context,
//        PdfRect.fromLTRB(left, top + font.descent + font.ascent + 1, right,
//            bottom));

    super.paintRect(
        context,
        PdfRect.fromLTRB(left, bottom, right,
            top + font.descent + font.ascent + 1));
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
      this.gridTextStyle}) {
    yAxis = List<double>.generate(
        xAxisIntersect + 1,
        (int i) =>
            i / xAxisIntersect.toDouble() * data.reduce(math.max).ceil());
    xAxis ??= List<double>.generate(data.length, (int i) => i.toDouble());

    var maxValue = data.reduce(
        (max, y) => max.toString().length > y.toString().length ? max : y);

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
  List<double> xAxis;
  List<double> yAxis;
  int xAxisMargin;
  int yAxisMargin;
  final TextStyle gridTextStyle;
  Axes axes;
  PdfRect gridBox;

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

    final maxValue = data.reduce(
        (max, y) => max.toString().length > y.toString().length ? max : y);
    final maxTextWidth =
        (font.stringMetrics(maxValue.toString()) * (style.fontSize)).width;
    final textHeight = (font.stringMetrics(' ') * (style.fontSize)).height;

    var gridBox = PdfRect.fromLTRB(
        box.left + maxTextWidth + xAxisMargin,
        box.top - textHeight / 2,
        box.right - maxTextWidth / 2,
        box.bottom + textHeight + yAxisMargin);

    axes.paint(
      context,
      PdfRect(0, 0, box.width, box.height),
    );

    // TODO cleanup this mess
    int i = 1;
    double pointSize = 3;

    var dataMax = data.reduce(math.max);
    for (var point in data) {
      print(point / maxValue);
      context.canvas
        ..setColor(PdfColors.red)
        ..setLineWidth(3)
        ..drawEllipse(
            gridBox.left +
                (gridBox.right - gridBox.left) * i / xAxis.last -
                pointSize / 2,
            gridBox.top -
                gridBox.bottom +
                yAxisMargin +
                textHeight +
                font.descent +
                font.ascent -
                pointSize / 2,
            pointSize,
            pointSize)
        ..fillPath();
      i++;
    }

//    for (int i = 0; i < xData.length; i++) {
//      context.canvas
//          ..setFillColor(PdfColor.fromRYB(0.9, 0.9, 0.9))
//          ..drawEllipse(xData[i], yData[i], 10, 10);

//      context.canvas
//        ..setStrokeColor(PdfColor.fromRYB(0.9, 0.9, 0.9))
//        ..setFillColor(PdfColor.fromRYB(0.9, 0.9, 0.9))
//        ..setLineWidth(10)
//        ..moveTo(gridTextSize * 2, gridTextSize * 2)
//        ..drawEllipse(
//            xData[i] * (box.width - gridTextSize * 2.5) / xMax +
//                gridTextSize * 2,
//            yData[i] * (box.height - gridTextSize * 2.5) / yMax +
//                gridTextSize * 2,
//            2,
//            2)
//        ..strokePath();
//    }

    context.canvas.restoreContext();
  }
}
