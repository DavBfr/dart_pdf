import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

const PdfColor green = PdfColor.fromInt(0xff9ce5d0);
const PdfColor lightGreen = PdfColor.fromInt(0xffcdf1e7);

PageTheme myPageTheme(PdfPageFormat format) {
  return PageTheme(
    pageFormat: format.applyMargin(
        left: 2.0 * PdfPageFormat.cm,
        top: 4.0 * PdfPageFormat.cm,
        right: 2.0 * PdfPageFormat.cm,
        bottom: 2.0 * PdfPageFormat.cm),
    buildBackground: (Context context) {
      return FullPage(
        ignoreMargins: true,
        child: CustomPaint(
          size: PdfPoint(format.width, format.height),
          painter: (PdfGraphics canvas, PdfPoint size) {
            context.canvas
              ..setColor(lightGreen)
              ..moveTo(0, size.y)
              ..lineTo(0, size.y - 230)
              ..lineTo(60, size.y)
              ..fillPath()
              ..setColor(green)
              ..moveTo(0, size.y)
              ..lineTo(0, size.y - 100)
              ..lineTo(100, size.y)
              ..fillPath()
              ..setColor(lightGreen)
              ..moveTo(30, size.y)
              ..lineTo(110, size.y - 50)
              ..lineTo(150, size.y)
              ..fillPath()
              ..moveTo(size.x, 0)
              ..lineTo(size.x, 230)
              ..lineTo(size.x - 60, 0)
              ..fillPath()
              ..setColor(green)
              ..moveTo(size.x, 0)
              ..lineTo(size.x, 100)
              ..lineTo(size.x - 100, 0)
              ..fillPath()
              ..setColor(lightGreen)
              ..moveTo(size.x - 30, 0)
              ..lineTo(size.x - 110, 50)
              ..lineTo(size.x - 150, 0)
              ..fillPath();
          },
        ),
      );
    },
  );
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
