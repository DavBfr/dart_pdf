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

/// Represents an RGB color
class PdfColor {
  /// Create a color with red, green, blue and alpha components
  /// values between 0 and 1
  const PdfColor(this.red, this.green, this.blue, [this.alpha = 1.0])
      : assert(red >= 0 && red <= 1),
        assert(green >= 0 && green <= 1),
        assert(blue >= 0 && blue <= 1),
        assert(alpha >= 0 && alpha <= 1);

  /// Return a color with: 0xAARRGGBB
  const PdfColor.fromInt(int color)
      : red = (color >> 16 & 0xff) / 255.0,
        green = (color >> 8 & 0xff) / 255.0,
        blue = (color & 0xff) / 255.0,
        alpha = (color >> 24 & 0xff) / 255.0;

  /// Can parse colors in the form:
  /// * #RRGGBBAA
  /// * #RRGGBB
  /// * #RGB
  /// * RRGGBBAA
  /// * RRGGBB
  /// * RGB
  factory PdfColor.fromHex(String color) {
    if (color.startsWith('#')) {
      color = color.substring(1);
    }

    double red;
    double green;
    double blue;
    var alpha = 1.0;

    if (color.length == 3) {
      red = int.parse(color.substring(0, 1) * 2, radix: 16) / 255;
      green = int.parse(color.substring(1, 2) * 2, radix: 16) / 255;
      blue = int.parse(color.substring(2, 3) * 2, radix: 16) / 255;
      return PdfColor(red, green, blue, alpha);
    }

    assert(color.length == 3 || color.length == 6 || color.length == 8);

    red = int.parse(color.substring(0, 2), radix: 16) / 255;
    green = int.parse(color.substring(2, 4), radix: 16) / 255;
    blue = int.parse(color.substring(4, 6), radix: 16) / 255;

    if (color.length == 8) {
      alpha = int.parse(color.substring(6, 8), radix: 16) / 255;
    }

    return PdfColor(red, green, blue, alpha);
  }

  /// Load an RGB color from a RYB color
  factory PdfColor.fromRYB(double red, double yellow, double blue,
      [double alpha = 1.0]) {
    assert(red >= 0 && red <= 1);
    assert(yellow >= 0 && yellow <= 1);
    assert(blue >= 0 && blue <= 1);
    assert(alpha >= 0 && alpha <= 1);

    const magic = <List<double>>[
      <double>[1, 1, 1],
      <double>[1, 1, 0],
      <double>[1, 0, 0],
      <double>[1, 0.5, 0],
      <double>[0.163, 0.373, 0.6],
      <double>[0.0, 0.66, 0.2],
      <double>[0.5, 0.0, 0.5],
      <double>[0.2, 0.094, 0.0]
    ];

    double cubicInt(double t, double A, double B) {
      final weight = t * t * (3 - 2 * t);
      return A + weight * (B - A);
    }

    double getRed(double iR, double iY, double iB) {
      final x0 = cubicInt(iB, magic[0][0], magic[4][0]);
      final x1 = cubicInt(iB, magic[1][0], magic[5][0]);
      final x2 = cubicInt(iB, magic[2][0], magic[6][0]);
      final x3 = cubicInt(iB, magic[3][0], magic[7][0]);
      final y0 = cubicInt(iY, x0, x1);
      final y1 = cubicInt(iY, x2, x3);
      return cubicInt(iR, y0, y1);
    }

    double getGreen(double iR, double iY, double iB) {
      final x0 = cubicInt(iB, magic[0][1], magic[4][1]);
      final x1 = cubicInt(iB, magic[1][1], magic[5][1]);
      final x2 = cubicInt(iB, magic[2][1], magic[6][1]);
      final x3 = cubicInt(iB, magic[3][1], magic[7][1]);
      final y0 = cubicInt(iY, x0, x1);
      final y1 = cubicInt(iY, x2, x3);
      return cubicInt(iR, y0, y1);
    }

    double getBlue(double iR, double iY, double iB) {
      final x0 = cubicInt(iB, magic[0][2], magic[4][2]);
      final x1 = cubicInt(iB, magic[1][2], magic[5][2]);
      final x2 = cubicInt(iB, magic[2][2], magic[6][2]);
      final x3 = cubicInt(iB, magic[3][2], magic[7][2]);
      final y0 = cubicInt(iY, x0, x1);
      final y1 = cubicInt(iY, x2, x3);
      return cubicInt(iR, y0, y1);
    }

    final redValue = getRed(red, yellow, blue);
    final greenValue = getGreen(red, yellow, blue);
    final blueValue = getBlue(red, yellow, blue);
    return PdfColor(redValue, greenValue, blueValue, alpha);
  }

  /// Opacity
  final double alpha;

  /// Red component
  final double red;

  /// Green component
  final double green;

  /// Blue component
  final double blue;

  /// Get the int32 representation of this color
  int toInt() =>
      ((((alpha * 255.0).round() & 0xff) << 24) |
          (((red * 255.0).round() & 0xff) << 16) |
          (((green * 255.0).round() & 0xff) << 8) |
          (((blue * 255.0).round() & 0xff) << 0)) &
      0xFFFFFFFF;

  /// Get an Hexadecimal representation of this color
  String toHex() {
    final i = toInt();
    final rgb = (i & 0xffffff).toRadixString(16);
    final a = ((i & 0xff000000) >> 24).toRadixString(16);
    return '#$rgb$a';
  }

  /// Convert this color to CMYK
  PdfColorCmyk toCmyk() {
    return PdfColorCmyk.fromRgb(red, green, blue, alpha);
  }

  /// Convert this color to HSV
  PdfColorHsv toHsv() {
    return PdfColorHsv.fromRgb(red, green, blue, alpha);
  }

  /// Convert this color to HSL
  PdfColorHsl toHsl() {
    return PdfColorHsl.fromRgb(red, green, blue, alpha);
  }

  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return math.pow((component + 0.055) / 1.055, 2.4);
  }

  /// Get the luminance
  double get luminance {
    final R = _linearizeColorComponent(red);
    final G = _linearizeColorComponent(green);
    final B = _linearizeColorComponent(blue);
    return 0.2126 * R + 0.7152 * G + 0.0722 * B;
  }

  /// Build a Material Color shade using the given [strength].
  ///
  /// To lighten a color, set the [strength] value to < .5
  /// To darken a color, set the [strength] value to > .5
  PdfColor shade(double strength) {
    final ds = 1.5 - strength;
    final hsl = toHsl();

    return PdfColorHsl(
        hsl.hue, hsl.saturation, (hsl.lightness * ds).clamp(0.0, 1.0));
  }

  /// Get a complementary color with hue shifted by -120°
  PdfColor get complementary => toHsv().complementary;

  /// Get some similar colors
  List<PdfColor> get monochromatic => toHsv().monochromatic;

  /// Returns a list of complementary colors
  List<PdfColor> get splitcomplementary => toHsv().splitcomplementary;

  /// Returns a list of tetradic colors
  List<PdfColor> get tetradic => toHsv().tetradic;

  /// Returns a list of triadic colors
  List<PdfColor> get triadic => toHsv().triadic;

  /// Returns a list of analagous colors
  List<PdfColor> get analagous => toHsv().analagous;

  @override
  String toString() => '$runtimeType($red, $green, $blue, $alpha)';
}

/// Represents an CMYK color
class PdfColorCmyk extends PdfColor {
  /// Creates a CMYK color
  const PdfColorCmyk(this.cyan, this.magenta, this.yellow, this.black,
      [double a = 1.0])
      : super((1.0 - cyan) * (1.0 - black), (1.0 - magenta) * (1.0 - black),
            (1.0 - yellow) * (1.0 - black), a);

  /// Create a CMYK color from red ,green and blue components
  const PdfColorCmyk.fromRgb(double r, double g, double b, [double a = 1.0])
      : black = 1.0 - r > g
            ? r
            : g > b
                ? r > g
                    ? r
                    : g
                : b,
        cyan = (1.0 -
                r -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)) /
            (1.0 -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)),
        magenta = (1.0 -
                g -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)) /
            (1.0 -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)),
        yellow = (1.0 -
                b -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)) /
            (1.0 -
                (1.0 - r > g
                    ? r
                    : g > b
                        ? r > g
                            ? r
                            : g
                        : b)),
        super(r, g, b, a);

  /// Cyan component
  final double cyan;

  /// Magenta component
  final double magenta;

  /// Yellow component
  final double yellow;

  /// Black component
  final double black;

  @override
  PdfColorCmyk toCmyk() {
    return this;
  }

  @override
  String toString() => '$runtimeType($cyan, $magenta, $yellow, $black, $alpha)';
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

/// Same as HSB, Cylindrical geometries with hue, their angular dimension,
/// starting at the red primary at 0°, passing through the green primary
/// at 120° and the blue primary at 240°, and then wrapping back to red at 360°
class PdfColorHsv extends PdfColor {
  /// Creates an HSV color
  factory PdfColorHsv(double hue, double saturation, double value,
      [double alpha = 1.0]) {
    final chroma = saturation * value;
    final secondary = chroma * (1.0 - (((hue / 60.0) % 2.0) - 1.0).abs());
    final match = value - chroma;

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

    return PdfColorHsv._(hue, saturation, value, (red + match).clamp(0.0, 1.0),
        (green + match).clamp(0.0, 1.0), (blue + match).clamp(0.0, 1.0), alpha);
  }

  const PdfColorHsv._(this.hue, this.saturation, this.value, double red,
      double green, double blue, double alpha)
      : assert(hue >= 0 && hue < 360),
        assert(saturation >= 0 && saturation <= 1),
        assert(value >= 0 && value <= 1),
        super(red, green, blue, alpha);

  /// Creates an HSV color from red, green, blue components
  factory PdfColorHsv.fromRgb(double red, double green, double blue,
      [double alpha = 1.0]) {
    final max = math.max(red, math.max(green, blue));
    final min = math.min(red, math.min(green, blue));
    final delta = max - min;

    final hue = _getHue(red, green, blue, max, delta);
    final saturation = max == 0.0 ? 0.0 : delta / max;

    return PdfColorHsv._(hue, saturation, max, red, green, blue, alpha);
  }

  /// Angular position the colorspace coordinate diagram in degrees from 0° to 360°
  final double hue;

  /// Saturation of the color
  final double saturation;

  /// Brightness
  final double value;

  @override
  PdfColorHsv toHsv() {
    return this;
  }

  /// Get a complementary color with hue shifted by -120°
  @override
  PdfColorHsv get complementary =>
      PdfColorHsv((hue - 120) % 360, saturation, value, alpha);

  /// Get a similar color
  @override
  List<PdfColorHsv> get monochromatic => <PdfColorHsv>[
        PdfColorHsv(
            hue,
            (saturation > 0.5 ? saturation - 0.2 : saturation + 0.2)
                .clamp(0, 1),
            (value > 0.5 ? value - 0.1 : value + 0.1).clamp(0, 1)),
        PdfColorHsv(
            hue,
            (saturation > 0.5 ? saturation - 0.4 : saturation + 0.4)
                .clamp(0, 1),
            (value > 0.5 ? value - 0.2 : value + 0.2).clamp(0, 1)),
        PdfColorHsv(
            hue,
            (saturation > 0.5 ? saturation - 0.15 : saturation + 0.15)
                .clamp(0, 1),
            (value > 0.5 ? value - 0.05 : value + 0.05).clamp(0, 1))
      ];

  /// Get two complementary colors with hue shifted by -120°
  @override
  List<PdfColorHsv> get splitcomplementary => <PdfColorHsv>[
        PdfColorHsv((hue - 150) % 360, saturation, value, alpha),
        PdfColorHsv((hue - 180) % 360, saturation, value, alpha),
      ];

  @override
  List<PdfColorHsv> get triadic => <PdfColorHsv>[
        PdfColorHsv((hue + 80) % 360, saturation, value, alpha),
        PdfColorHsv((hue - 120) % 360, saturation, value, alpha),
      ];

  @override
  List<PdfColorHsv> get tetradic => <PdfColorHsv>[
        PdfColorHsv((hue + 120) % 360, saturation, value, alpha),
        PdfColorHsv((hue - 150) % 360, saturation, value, alpha),
        PdfColorHsv((hue + 60) % 360, saturation, value, alpha),
      ];

  @override
  List<PdfColorHsv> get analagous => <PdfColorHsv>[
        PdfColorHsv((hue + 30) % 360, saturation, value, alpha),
        PdfColorHsv((hue - 20) % 360, saturation, value, alpha),
      ];

  @override
  String toString() => '$runtimeType($hue, $saturation, $value, $alpha)';
}

/// Represents an HSL color
class PdfColorHsl extends PdfColor {
  /// Creates an HSL color
  factory PdfColorHsl(double hue, double saturation, double lightness,
      [double alpha = 1.0]) {
    final chroma = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation;
    final secondary = chroma * (1.0 - (((hue / 60.0) % 2.0) - 1.0).abs());
    final match = lightness - chroma / 2.0;

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
    return PdfColorHsl._(
        hue,
        saturation,
        lightness,
        alpha,
        (red + match).clamp(0.0, 1.0),
        (green + match).clamp(0.0, 1.0),
        (blue + match).clamp(0.0, 1.0));
  }

  const PdfColorHsl._(this.hue, this.saturation, this.lightness, double alpha,
      double red, double green, double blue)
      : assert(hue >= 0 && hue < 360),
        assert(saturation >= 0 && saturation <= 1),
        assert(lightness >= 0 && lightness <= 1),
        super(red, green, blue, alpha);

  /// Creates an HSL color from red, green, and blue components
  factory PdfColorHsl.fromRgb(double red, double green, double blue,
      [double alpha = 1.0]) {
    final max = math.max(red, math.max(green, blue));
    final min = math.min(red, math.min(green, blue));
    final delta = max - min;

    final hue = _getHue(red, green, blue, max, delta);
    final lightness = (max + min) / 2.0;
    // Saturation can exceed 1.0 with rounding errors, so clamp it.
    final double saturation = lightness == 1.0
        ? 0.0
        : (delta / (1.0 - (2.0 * lightness - 1.0).abs())).clamp(0.0, 1.0);
    return PdfColorHsl._(hue, saturation, lightness, alpha, red, green, blue);
  }

  /// Hue component
  final double hue;

  /// Saturation component
  final double saturation;

  /// Lightness component
  final double lightness;

  @override
  PdfColorHsl toHsl() {
    return this;
  }

  @override
  String toString() => '$runtimeType($hue, $saturation, $lightness, $alpha)';
}
