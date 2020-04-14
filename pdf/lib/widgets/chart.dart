part of widget;

abstract class Chart extends Widget {
  Chart(
      {@required this.xData,
      @required this.yData,
      this.width = 200,
      this.height = 100,
      this.fit = BoxFit.contain,
      this.separatorEvery = 4,
      this.font,
      this.gridTextSize = 12}) {
    axes = Axes(
      xMax: xData.reduce(math.max),
      yMax: yData.reduce(math.max),
      separatorEvery: separatorEvery,
      font: font,
      gridTextSize: gridTextSize,
    );
  }

  final double width;
  final double height;
  final BoxFit fit;
  final List<double> xData;
  final List<double> yData;
  final int separatorEvery;
  final PdfFont font;
  final double gridTextSize;
  Axes axes;
}

class Axes extends BoxBorder {
  Axes(
      {this.xMax, this.yMax, this.separatorEvery, this.font, this.gridTextSize})
      : super(left: true, bottom: true);

  final double xMax;
  final double yMax;
  final int separatorEvery;
  final PdfFont font;
  final double gridTextSize;

  void paint(Context context, PdfRect box,
      [List<double> widths, List<double> heights]) {

    super.paintRect(context,
        PdfRect.fromLTRB(box.left + gridTextSize*1.25, box.bottom + gridTextSize*1.25, box.right, box.top));

    for (int sep = 0; sep <= xMax.ceil().toInt(); sep += separatorEvery) {
      context.canvas
        ..setColor(PdfColor.fromRYB(1, 1, 1))
        ..drawString(font, gridTextSize, sep.toString(), 0,
            box.top / xMax.ceil().toInt() * sep - (sep == 0 ? 0 : gridTextSize*(2/3)));
    }

    for (int sep = 0; sep <= yMax.ceil().toInt(); sep += separatorEvery) {
      context.canvas
        ..setColor(PdfColor.fromRYB(1, 1, 1))
        ..drawString(font, gridTextSize, sep.toString(),
            box.right / yMax.ceil().toInt() * sep - (sep == 0 ? 0 : gridTextSize*(2/3)), 0);
    }
  }
}

class ScatterChart extends Chart {
  ScatterChart(
      {List<double> xData,
      List<double> yData,
      double width = 200,
      double height = 100,
      BoxFit fit = BoxFit.contain,
      int separatorEvery = 4,
      PdfFont font,
      double gridTextSize = 12})
      : super(
          xData: xData,
          yData: yData,
          width: width,
          height: height,
          fit: fit,
          separatorEvery: separatorEvery,
          font: font,
          gridTextSize: gridTextSize,
        );
  PdfRect rect;

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

    return;
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    axes.paint(context, PdfRect(0, 0, box.width, box.height));

    context.canvas.restoreContext();
  }
}
