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

part of pdf;

class PdfColor {
  const PdfColor(this.r, this.g, this.b, [this.a = 1.0]);

  const PdfColor.fromInt(int color)
      : r = (color >> 16 & 0xff) / 255.0,
        g = (color >> 8 & 0xff) / 255.0,
        b = (color & 0xff) / 255.0,
        a = (color >> 24 & 0xff) / 255.0;

  factory PdfColor.fromHex(String color) {
    if (color.startsWith('#')) {
      color = color.substring(1);
    }
    return PdfColor(
        (int.parse(color.substring(0, 1), radix: 16) >> 16 & 0xff) / 255.0,
        (int.parse(color.substring(2, 3), radix: 16) >> 8 & 0xff) / 255.0,
        (int.parse(color.substring(4, 5), radix: 16) & 0xff) / 255.0,
        (int.parse(color.substring(6, 7), radix: 16) >> 24 & 0xff) / 255.0);
  }

  final double a;
  final double r;
  final double g;
  final double b;

  @deprecated
  static const PdfColor black = PdfColors.black;
  @deprecated
  static const PdfColor white = PdfColors.white;
  @deprecated
  static const PdfColor red = PdfColors.red;
  @deprecated
  static const PdfColor pink = PdfColors.pink;
  @deprecated
  static const PdfColor purple = PdfColors.purple;
  @deprecated
  static const PdfColor deepPurple = PdfColors.deepPurple;
  @deprecated
  static const PdfColor indigo = PdfColors.indigo;
  @deprecated
  static const PdfColor blue = PdfColors.blue;
  @deprecated
  static const PdfColor lightBlue = PdfColors.lightBlue;
  @deprecated
  static const PdfColor cyan = PdfColors.cyan;
  @deprecated
  static const PdfColor teal = PdfColors.teal;
  @deprecated
  static const PdfColor green = PdfColors.green;
  @deprecated
  static const PdfColor lightGreen = PdfColors.lightGreen;
  @deprecated
  static const PdfColor lime = PdfColors.lime;
  @deprecated
  static const PdfColor yellow = PdfColors.yellow;
  @deprecated
  static const PdfColor amber = PdfColors.amber;
  @deprecated
  static const PdfColor orange = PdfColors.orange;
  @deprecated
  static const PdfColor deepOrange = PdfColors.deepOrange;
  @deprecated
  static const PdfColor brown = PdfColors.brown;
  @deprecated
  static const PdfColor grey = PdfColors.grey;
  @deprecated
  static const PdfColor blueGrey = PdfColors.blueGrey;

  int toInt() =>
      ((((a * 255.0).round() & 0xff) << 24) |
          (((r * 255.0).round() & 0xff) << 16) |
          (((g * 255.0).round() & 0xff) << 8) |
          (((b * 255.0).round() & 0xff) << 0)) &
      0xFFFFFFFF;

  String toHex() => '#' + toInt().toRadixString(16);

  PdfColorCmyk toCmyk() {
    return PdfColorCmyk.fromRgb(r, g, b, a);
  }

  PdfColorHsv toHsv() {
    return PdfColorHsv.fromRgb(r, g, b, a);
  }

  PdfColorHsl toHsl() {
    return PdfColorHsl.fromRgb(r, g, b, a);
  }

  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return math.pow((component + 0.055) / 1.055, 2.4);
  }

  double get luminance {
    final double R = _linearizeColorComponent(r);
    final double G = _linearizeColorComponent(g);
    final double B = _linearizeColorComponent(b);
    return 0.2126 * R + 0.7152 * G + 0.0722 * B;
  }

  @override
  String toString() => '$runtimeType($r, $g, $b, $a)';
}

class PdfColorCmyk extends PdfColor {
  const PdfColorCmyk(this.c, this.m, this.y, this.k, [double a = 1.0])
      : super((1.0 - c) * (1.0 - k), (1.0 - m) * (1.0 - k),
            (1.0 - y) * (1.0 - k), a);

  const PdfColorCmyk.fromRgb(double r, double g, double b, [double a = 1.0])
      : k = 1.0 - r > g ? r : g > b ? r > g ? r : g : b,
        c = (1.0 - r - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)) /
            (1.0 - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)),
        m = (1.0 - g - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)) /
            (1.0 - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)),
        y = (1.0 - b - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)) /
            (1.0 - (1.0 - r > g ? r : g > b ? r > g ? r : g : b)),
        super(r, g, b, a);

  final double c;
  final double m;
  final double y;
  final double k;

  @override
  PdfColorCmyk toCmyk() {
    return this;
  }

  @override
  String toString() => '$runtimeType($c, $m, $y, $k, $a)';
}

double _getHue(
    double red, double green, double blue, double max, double delta) {
  double hue;
  if (max == 0.0) {
    hue = 0.0;
  } else if (max == red) {
    hue = 60.0 * (((green - blue) / delta) % 6);
  } else if (max == green) {
    hue = 60.0 * (((blue - red) / delta) + 2);
  } else if (max == blue) {
    hue = 60.0 * (((red - green) / delta) + 4);
  }

  /// Set hue to 0.0 when red == green == blue.
  hue = hue.isNaN ? 0.0 : hue;
  return hue;
}

class PdfColorHsv extends PdfColor {
  factory PdfColorHsv(double hue, double saturation, double value,
      [double alpha = 1.0]) {
    final double chroma = saturation * value;
    final double secondary =
        chroma * (1.0 - (((hue / 60.0) % 2.0) - 1.0).abs());
    final double match = value - chroma;

    double red;
    double green;
    double blue;
    if (hue < 60.0) {
      red = chroma;
      green = secondary;
      blue = 0.0;
    } else if (hue < 120.0) {
      red = secondary;
      green = chroma;
      blue = 0.0;
    } else if (hue < 180.0) {
      red = 0.0;
      green = chroma;
      blue = secondary;
    } else if (hue < 240.0) {
      red = 0.0;
      green = secondary;
      blue = chroma;
    } else if (hue < 300.0) {
      red = secondary;
      green = 0.0;
      blue = chroma;
    } else {
      red = chroma;
      green = 0.0;
      blue = secondary;
    }

    return PdfColorHsv._(hue, saturation, value, red + match, green + match,
        blue + match, alpha);
  }

  const PdfColorHsv._(this.hue, this.saturation, this.value, double red,
      double green, double blue, double alpha)
      : super(red, green, blue, alpha);

  factory PdfColorHsv.fromRgb(double red, double green, double blue,
      [double alpha]) {
    final double max = math.max(red, math.max(green, blue));
    final double min = math.min(red, math.min(green, blue));
    final double delta = max - min;

    final double hue = _getHue(red, green, blue, max, delta);
    final double saturation = max == 0.0 ? 0.0 : delta / max;

    return PdfColorHsv._(hue, saturation, max, red, green, blue, alpha);
  }

  final double hue;
  final double saturation;
  final double value;

  @override
  PdfColorHsv toHsv() {
    return this;
  }

  @override
  String toString() => '$runtimeType($hue, $saturation, $value, $a)';
}

class PdfColorHsl extends PdfColor {
  factory PdfColorHsl(double hue, double saturation, double lightness,
      [double alpha]) {
    final double chroma = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation;
    final double secondary =
        chroma * (1.0 - (((hue / 60.0) % 2.0) - 1.0).abs());
    final double match = lightness - chroma / 2.0;

    double red;
    double green;
    double blue;
    if (hue < 60.0) {
      red = chroma;
      green = secondary;
      blue = 0.0;
    } else if (hue < 120.0) {
      red = secondary;
      green = chroma;
      blue = 0.0;
    } else if (hue < 180.0) {
      red = 0.0;
      green = chroma;
      blue = secondary;
    } else if (hue < 240.0) {
      red = 0.0;
      green = secondary;
      blue = chroma;
    } else if (hue < 300.0) {
      red = secondary;
      green = 0.0;
      blue = chroma;
    } else {
      red = chroma;
      green = 0.0;
      blue = secondary;
    }
    return PdfColorHsl._(hue, saturation, lightness, alpha, red + match,
        green + match, blue + match);
  }

  const PdfColorHsl._(this.hue, this.saturation, this.lightness, double alpha,
      double red, double green, double blue)
      : super(red, green, blue, alpha);

  factory PdfColorHsl.fromRgb(double red, double green, double blue,
      [double alpha]) {
    final double max = math.max(red, math.max(green, blue));
    final double min = math.min(red, math.min(green, blue));
    final double delta = max - min;

    final double hue = _getHue(red, green, blue, max, delta);
    final double lightness = (max + min) / 2.0;
    // Saturation can exceed 1.0 with rounding errors, so clamp it.
    final double saturation = lightness == 1.0
        ? 0.0
        : (delta / (1.0 - (2.0 * lightness - 1.0).abs())).clamp(0.0, 1.0);
    return PdfColorHsl._(hue, saturation, lightness, alpha, red, green, blue);
  }

  final double hue;
  final double saturation;
  final double lightness;

  @override
  PdfColorHsl toHsl() {
    return this;
  }

  @override
  String toString() => '$runtimeType($hue, $saturation, $lightness, $a)';
}
