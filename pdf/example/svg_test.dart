import 'dart:io';

import '../lib/widgets.dart' as pw;

void main() async {
  final svgImage = pw.SvgImage(svg: svgRaw, fontFallback: [
    pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Roboto/Roboto-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
    pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Shantell_Sans/static/ShantellSans-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
    pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Noto/NotoSansTC-Regular.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
    pw.Font.ttf(File(
            '../../../secondlayer/napkin-web-client/web/fonts/Noto/NotoEmoji-VariableFont_wght.ttf')
        .readAsBytesSync()
        .buffer
        .asByteData()),
  ]);

  final pdf = pw.Document(userDocumentID: '1234567890');

  pdf.addPage(pw.Page(
      build: (pw.Context context) =>
          pw.Positioned(left: 100, top: 300, child: svgImage)));

  File('example.pdf').writeAsBytesSync(await pdf.save());
}

const svgRaw = '''
<svg width="1128" height="156" viewBox="0 0 1128 156" style="fill:none;stroke:none;fill-rule:evenodd;clip-rule:evenodd;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:1.5;" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
	<g id="blend" style="mix-blend-mode:blend">
		<g id="g-root-tx_1q5q08xr8c7in-fill" data-item-order="0" data-item-id="tx_1q5q08xr8c7in" data-item-class="Label Stroke" data-item-index="none" data-renderer-id="0" transform="translate(0, 68)">
			<g id="tx_1q5q08xr8c7in-fill" stroke="none" fill="#484848">
				<g xmlns="http://www.w3.org/2000/svg">
					<text width="500" x="0" y="0" height="24" dominant-baseline="ideographic" text-anchor="start" style="font: 30px 'Source Code Pro', monospace; letter-spacing: 0.01rem; white-space: pre;">
						<tspan x="0" y="24">
							Eng+FçasÜ + 中文+かな+자기+इस
						</tspan>
					</text>
				</g>
			</g>
		</g>
	</g>
</svg>
''';
