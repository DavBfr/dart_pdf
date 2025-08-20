import 'dart:io';
import 'package:bidi/bidi.dart' as bidi;

import '../lib/widgets.dart' as pw;
import '../lib/pdf.dart';


void main() async {
  final svgImage = pw.SvgImage(svg: svgRaw(), fonts: {
    'roboto': [pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Roboto/Roboto-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
    pw.Font.ttf(File(
                '../../../secondlayer/napkin-web-client/web/fonts/Roboto/Roboto-Bold.ttf')
            .readAsBytesSync()
            .buffer
            .asByteData())],
    'shantell sans': [pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Shantell_Sans/static/ShantellSans-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData())],
    },
    defaultFont: pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Roboto/Roboto-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
    fallbackFonts: [
    pw.Font.ttf(File(
            '/Users/arnaudbrejeon/secondLayer/src/secondlayer/napkin-web-client/web/fonts/Noto_Sans_Kannada/static/NotoSansKannada-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),pw.Font.ttf(File(
                '/Users/arnaudbrejeon/secondLayer/src/secondlayer/napkin-web-client/web/fonts/Noto_Sans_Kannada/static/NotoSansKannada-Bold.ttf')
            .readAsBytesSync()
            .buffer
            .asByteData()),
            ]);

  final pdf = pw.Document(userDocumentID: '1234567890');

  pdf.addPage(pw.Page(
      build: (pw.Context context) =>
          pw.Positioned(left: 100, top: 300, child: svgImage)));

  File('example.pdf').writeAsBytesSync(await pdf.save());

  // Shaping().dispose();
}

String svgRaw() => '''
<svg width="1128" height="500" viewBox="0 0 1128 500" style="fill:none;stroke:none;fill-rule:evenodd;clip-rule:evenodd;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:1.5;" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
	<g id="blend" style="mix-blend-mode:blend">
		<g id="g-root-tx_1q5q08xr8c7in-fill" data-item-order="0" data-item-id="tx_1q5q08xr8c7in" data-item-class="Label Stroke" data-item-index="none" data-renderer-id="0" transform="translate(0, 68)">
			<g id="tx_1q5q08xr8c7in-fill" stroke="none" fill="#484848">
    		 <text style="font: 30px 'Times new roman', serif; white-space: pre;">
    			<!-- <tspan x="80" y="100" dominant-baseline="ideographic"> ಇಲ್ಲ ಪಕ್ಕದಲ್ಲಿ ಹಾಂ ಬಳ ನೀವು ಹಾಂ </tspan> -->
          <tspan x="80" y="100" dominant-baseline="ideographic"> ABCDE</tspan>
    		</text>
     		 <text style="font: 30px 'Helvetica', serif; white-space: pre;">
     			<tspan x="80" y="150" dominant-baseline="ideographic">ABC !!</tspan>
      		</text>
     		 <text style="font: 30px 'Courier', serif; white-space: pre;">
     			<tspan x="80" y="200" dominant-baseline="ideographic">HIJ ${DateTime.now().millisecond}</tspan>
      		</text>
			</g>
		</g>
	</g>
</svg>
''';
