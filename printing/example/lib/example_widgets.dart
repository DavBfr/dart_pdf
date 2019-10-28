import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:qr/qr.dart';

const PdfColor green = PdfColor.fromInt(0xff9ce5d0);
const PdfColor lightGreen = PdfColor.fromInt(0xffcdf1e7);

class MyPage extends Page {
  MyPage(
      {PdfPageFormat pageFormat = PdfPageFormat.a4,
      BuildCallback build,
      EdgeInsets margin})
      : super(pageFormat: pageFormat, margin: margin, build: build);

  @override
  void paint(Widget child, Context context) {
    context.canvas
      ..setColor(lightGreen)
      ..moveTo(0, pageFormat.height)
      ..lineTo(0, pageFormat.height - 230)
      ..lineTo(60, pageFormat.height)
      ..fillPath()
      ..setColor(green)
      ..moveTo(0, pageFormat.height)
      ..lineTo(0, pageFormat.height - 100)
      ..lineTo(100, pageFormat.height)
      ..fillPath()
      ..setColor(lightGreen)
      ..moveTo(30, pageFormat.height)
      ..lineTo(110, pageFormat.height - 50)
      ..lineTo(150, pageFormat.height)
      ..fillPath()
      ..moveTo(pageFormat.width, 0)
      ..lineTo(pageFormat.width, 230)
      ..lineTo(pageFormat.width - 60, 0)
      ..fillPath()
      ..setColor(green)
      ..moveTo(pageFormat.width, 0)
      ..lineTo(pageFormat.width, 100)
      ..lineTo(pageFormat.width - 100, 0)
      ..fillPath()
      ..setColor(lightGreen)
      ..moveTo(pageFormat.width - 30, 0)
      ..lineTo(pageFormat.width - 110, 50)
      ..lineTo(pageFormat.width - 150, 0)
      ..fillPath();

    super.paint(child, context);
  }
}

class Block extends StatelessWidget {
  Block({this.title});

  final String title;

  @override
  Widget build(Context context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 2.5, left: 2, right: 5),
              decoration:
                  const BoxDecoration(color: green, shape: BoxShape.circle),
            ),
            Text(title,
                style: Theme.of(context)
                    .defaultTextStyle
                    .copyWith(fontWeight: FontWeight.bold)),
          ]),
          Container(
            decoration: const BoxDecoration(
                border: BoxBorder(left: true, color: green, width: 2)),
            padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
            margin: const EdgeInsets.only(left: 5),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Lorem(length: 20),
                ]),
          ),
        ]);
  }
}

class Category extends StatelessWidget {
  Category({this.title});

  final String title;

  @override
  Widget build(Context context) {
    return Container(
        decoration: const BoxDecoration(color: lightGreen, borderRadius: 6),
        margin: const EdgeInsets.only(bottom: 10, top: 20),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
        child: Text(title, textScaleFactor: 1.5));
  }
}

typedef QrError = void Function(dynamic error);

class _QrCodeWidget extends Widget {
  _QrCodeWidget({
    @required String data,
    this.version,
    this.errorCorrectionLevel,
    this.color,
    this.onError,
    this.gapless = false,
  })  : assert(data != null),
        _qr = version == null
            ? QrCode.fromData(
                data: data,
                errorCorrectLevel: errorCorrectionLevel,
              )
            : QrCode(
                version,
                errorCorrectionLevel,
              ) {
    // configure and make the QR code data
    try {
      if (version != null) {
        _qr.addData(data);
      }
      _qr.make();
    } catch (ex) {
      if (onError != null) {
        _hasError = true;
        onError(ex);
      }
    }
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  /// the qr code version
  final int version;

  /// the qr code error correction level
  final int errorCorrectionLevel;

  /// the color of the dark squares
  final PdfColor color;

  final QrError onError;

  final bool gapless;

  // our qr code data
  final QrCode _qr;

  bool _hasError = false;

  @override
  void paint(Context context) {
    super.paint(context);

    if (_hasError) {
      return;
    }

    final double shortestSide = box.width < box.height ? box.width : box.height;
    assert(shortestSide > 0);

    context.canvas.setFillColor(color);
    final double squareSize = shortestSide / _qr.moduleCount.toDouble();
    final int pxAdjustValue = gapless ? 1 : 0;
    for (int x = 0; x < _qr.moduleCount; x++) {
      for (int y = 0; y < _qr.moduleCount; y++) {
        if (_qr.isDark(y, x)) {
          context.canvas.drawRect(
            box.left + x * squareSize,
            box.top - (y + 1) * squareSize,
            squareSize + pxAdjustValue,
            squareSize + pxAdjustValue,
          );
        }
      }
    }

    context.canvas.fillPath();
  }
}

class QrCodeWidget extends StatelessWidget {
  QrCodeWidget({
    @required this.data,
    this.version,
    this.errorCorrectionLevel = QrErrorCorrectLevel.L,
    this.color = PdfColors.black,
    this.onError,
    this.gapless = false,
    this.size,
    this.padding,
  });

  /// the qr code data
  final String data;

  /// the qr code version
  final int version;

  /// the qr code error correction level
  final int errorCorrectionLevel;

  /// the color of the dark squares
  final PdfColor color;

  final QrError onError;

  final bool gapless;

  final double size;

  final EdgeInsets padding;

  @override
  Widget build(Context context) {
    Widget qrcode = AspectRatio(
        aspectRatio: 1.0,
        child: _QrCodeWidget(
          data: data,
          version: version,
          errorCorrectionLevel: errorCorrectionLevel,
          color: color,
          onError: onError,
          gapless: gapless,
        ));

    if (padding != null) {
      qrcode = Padding(padding: padding, child: qrcode);
    }

    if (size != null) {
      qrcode = SizedBox(width: size, height: size, child: qrcode);
    }

    return qrcode;
  }
}

class Percent extends StatelessWidget {
  Percent({
    @required this.size,
    @required this.value,
    this.title,
    this.fontSize = 1.2,
    this.color = green,
    this.backgroundColor = PdfColors.grey300,
    this.strokeWidth = 5,
  }) : assert(size != null);

  final double size;

  final double value;

  final Widget title;

  final double fontSize;

  final PdfColor color;

  final PdfColor backgroundColor;

  final double strokeWidth;

  @override
  Widget build(Context context) {
    final List<Widget> widgets = <Widget>[
      Container(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: Text(
                '${(value * 100).round().toInt()}%',
                textScaleFactor: fontSize,
              ),
            ),
            CircularProgressIndicator(
              value: value,
              backgroundColor: backgroundColor,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ],
        ),
      )
    ];

    if (title != null) {
      widgets.add(title);
    }

    return Column(children: widgets);
  }
}

class UrlText extends StatelessWidget {
  UrlText(this.text, this.url);

  final String text;
  final String url;

  @override
  Widget build(Context context) {
    return UrlLink(
      destination: url,
      child: Text(text,
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: PdfColors.blue,
          )),
    );
  }
}
