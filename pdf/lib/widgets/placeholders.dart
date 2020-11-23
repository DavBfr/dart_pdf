/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/svg.dart';

import 'basic.dart';
import 'geometry.dart';
import 'image.dart';
import 'text.dart';
import 'text_style.dart';
import 'widget.dart';

class Placeholder extends Widget {
  Placeholder(
      {this.color = const PdfColor.fromInt(0xFF455A64),
      this.strokeWidth = 2.0,
      this.fallbackWidth = 400.0,
      this.fallbackHeight = 400.0});

  final PdfColor color;

  final double strokeWidth;

  final double fallbackWidth;

  final double fallbackHeight;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect(
        0,
        0,
        constraints.constrainWidth(
            constraints.hasBoundedWidth ? constraints.maxWidth : fallbackWidth),
        constraints.constrainHeight(constraints.hasBoundedHeight
            ? constraints.maxHeight
            : fallbackHeight));
  }

  @override
  void paint(Context context) {
    super.paint(context);

    context.canvas
      ..setStrokeColor(color)
      ..moveTo(box.x, box.y)
      ..lineTo(box.right, box.top)
      ..moveTo(box.x, box.top)
      ..lineTo(box.right, box.y)
      ..drawBox(box)
      ..setLineWidth(strokeWidth)
      ..strokePath();
  }
}

class PdfLogo extends StatelessWidget {
  PdfLogo({this.color = PdfColors.red, this.fit = BoxFit.contain});

  final PdfColor color;
  final BoxFit fit;

  static const String pdf =
      'M 2.424 26.712 L 2.424 26.712 C 2.076 26.712 1.742 26.599 1.457 26.386 C 0.416 25.605 0.276 24.736 0.342 24.144 C 0.524 22.516 2.537 20.812 6.327 19.076 C 7.831 15.78 9.262 11.719 10.115 8.326 C 9.117 6.154 8.147 3.336 8.854 1.683 C 9.102 1.104 9.411 0.66 9.988 0.468 C 10.216 0.392 10.792 0.296 11.004 0.296 C 11.508 0.296 11.951 0.945 12.265 1.345 C 12.56 1.721 13.229 2.518 11.892 8.147 C 13.24 10.931 15.15 13.767 16.98 15.709 C 18.291 15.472 19.419 15.351 20.338 15.351 C 21.904 15.351 22.853 15.716 23.24 16.468 C 23.56 17.09 23.429 17.817 22.85 18.628 C 22.293 19.407 21.525 19.819 20.63 19.819 C 19.414 19.819 17.998 19.051 16.419 17.534 C 13.582 18.127 10.269 19.185 7.591 20.356 C 6.755 22.13 5.954 23.559 5.208 24.607 C 4.183 26.042 3.299 26.712 2.424 26.712 Z M 5.086 21.586 C 2.949 22.787 2.078 23.774 2.015 24.33 C 2.005 24.422 1.978 24.664 2.446 25.022 C 2.595 24.975 3.465 24.578 5.086 21.586 Z M 18.723 17.144 C 19.538 17.771 19.737 18.088 20.27 18.088 C 20.504 18.088 21.171 18.078 21.48 17.647 C 21.629 17.438 21.687 17.304 21.71 17.232 C 21.587 17.167 21.424 17.035 20.535 17.035 C 20.03 17.036 19.395 17.058 18.723 17.144 Z M 11.253 10.562 C 10.538 13.036 9.594 15.707 8.579 18.126 C 10.669 17.315 12.941 16.607 15.075 16.106 C 13.725 14.538 12.376 12.58 11.253 10.562 Z M 10.646 2.1 C 10.548 2.133 9.316 3.857 10.742 5.316 C 11.691 3.201 10.689 2.086 10.646 2.1 Z';

  @override
  Widget build(Context context) {
    return Shape(pdf, width: 24, height: 27, fillColor: color, fit: fit);
  }
}

class FlutterLogo extends StatelessWidget {
  FlutterLogo({this.fit = BoxFit.contain});

  final BoxFit fit;

  @override
  Widget build(Context context) {
    return SvgImage(
      svg:
          '<?xml version="1.0" encoding="UTF-8"?><svg version="1.1" viewBox="0 0 256 317" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="a" x1="10%" x2="67%" y1="40%" y2="35%"><stop stop-color="#1a237e" stop-opacity=".4" offset="0"/><stop stop-color="#1a237e" stop-opacity="0" offset="1"/></linearGradient></defs><polygon points="157.67 0 0 157.67 48.801 206.47 255.27 0" fill="#54c5f8"/><polygon points="156.57 145.4 72.149 229.82 121.13 279.53 169.84 230.82 255.27 145.4" fill="#54c5f8"/><polygon points="121.13 279.53 158.21 316.61 255.27 316.61 169.84 230.82" fill="#01579b"/><polygon points="71.6 230.36 120.4 181.56 169.84 230.82 121.13 279.53" fill="#29b6f6"/><polygon points="121.13 279.53 189.44 253.83 167.85 233.75" fill="url(#a)" fill-opacity=".8"/></svg>',
      fit: fit,
    );
  }
}

class LoremText {
  LoremText({math.Random random}) : random = random ?? math.Random(978);

  final math.Random random;

  static final List<String> words =
      'ad adipiscing aliqua aliquip amet anim aute cillum commodo consectetur consequat culpa cupidatat deserunt do dolor dolore duis ea eiusmod elit enim esse est et eu ex excepteur exercitation fugiat id in incididunt ipsum irure labore laboris laborum lorem magna minim mollit nisi non nostrud nulla occaecat officia pariatur proident qui quis reprehenderit sed sint sit sunt tempor ullamco ut velit veniam voluptate'
          .split(' ');

  String word() {
    return words[random.nextInt(words.length - 1)];
  }

  String sentence(int length) {
    final wordList = <String>[];
    for (var i = 0; i < length; i++) {
      var w = word();
      if (i < length - 1 && random.nextInt(10) == 0) {
        w += ',';
      }
      wordList.add(w);
    }
    final text = wordList.join(' ') + '.';
    return text[0].toUpperCase() + text.substring(1);
  }

  String paragraph(int length) {
    var wordsCount = 0;
    final sentenceList = <String>[];
    var n = 0;
    while (wordsCount < length) {
      n++;
      if (n > 100) {
        break;
      }
      final count = math.min(length,
          math.max(10, math.min(3, random.nextInt(length - wordsCount))));
      sentenceList.add(sentence(count));
      wordsCount += count;
    }
    return sentenceList.join(' ');
  }
}

class Lorem extends StatelessWidget {
  Lorem(
      {this.length = 50,
      this.random,
      this.style,
      this.textAlign = TextAlign.left,
      this.softWrap = true,
      this.textScaleFactor = 1.0,
      this.maxLines});

  final int length;
  final math.Random random;
  final TextStyle style;
  final TextAlign textAlign;
  final bool softWrap;
  final double textScaleFactor;
  final int maxLines;

  @override
  Widget build(Context context) {
    final lorem = LoremText(random: random);
    final text = lorem.paragraph(length);

    return Text(text,
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines);
  }
}
