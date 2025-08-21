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

import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math_64.dart';

import 'color.dart';
import 'format/array.dart';
import 'format/name.dart';
import 'format/num.dart';
import 'format/stream.dart';
import 'graphic_state.dart';
import 'obj/font.dart';
import 'obj/graphic_stream.dart';
import 'obj/image.dart';
import 'obj/page.dart';
import 'obj/pattern.dart';
import 'obj/shading.dart';
import 'rect.dart';

/// Shape to be used at the corners of paths that are stroked
enum PdfLineJoin {
  /// The outer edges of the strokes for the two segments shall be extended until they meet at an angle, as in a picture frame. If the segments meet at too sharp an angle (as defined by the miter limit parameter, a bevel join shall be used instead.
  miter,

  /// An arc of a circle with a diameter equal to the line width shall be drawn around the point where the two segments meet, connecting the outer edges of the strokes for the two segments. This pie-slice-shaped figure shall be filled in, producing a rounded corner.
  round,

  /// The two segments shall be finished with butt caps and the resulting notch beyond the ends of the segments shall be filled with a triangle.
  bevel
}

/// Specify the shape that shall be used at the ends of open sub paths
/// and dashes, when they are stroked.
enum PdfLineCap {
  /// The stroke shall be squared off at the endpoint of the path. There shall be no projection beyond the end of the path.
  butt,

  /// A semicircular arc with a diameter equal to the line width shall be drawn around the endpoint and shall be filled in.
  round,

  /// The stroke shall continue beyond the endpoint of the path for a distance equal to half the line width and shall be squared off.
  square
}

/// Text rendering mode
enum PdfTextRenderingMode {
  /// Fill text
  fill,

  /// Stroke text
  stroke,

  /// Fill, then stroke text
  fillAndStroke,

  /// Neither fill nor stroke text (invisible)
  invisible,

  /// Fill text and add to path for clipping
  fillAndClip,

  /// Stroke text and add to path for clipping
  strokeAndClip,

  /// Fill, then stroke text and add to path for clipping
  fillStrokeAndClip,

  /// Add text to path for clipping
  clip
}

@immutable
class _PdfGraphicsContext {
  const _PdfGraphicsContext({
    required this.ctm,
  });
  final Matrix4 ctm;

  _PdfGraphicsContext copy() => _PdfGraphicsContext(
        ctm: ctm.clone(),
      );
}

/// Pdf drawing operations
class PdfGraphics {
  /// Create a new graphic canvas
  PdfGraphics(this._page, this._buf) {
    _context = _PdfGraphicsContext(ctm: Matrix4.identity());
  }

  /// Ellipse 4-spline magic number
  static const double _m4 = 0.551784;

  static const int _commentIndent = 35;
  static const int _indentAmount = 2;
  int _indent = _indentAmount;

  /// Graphic context
  late _PdfGraphicsContext _context;
  final Queue<_PdfGraphicsContext> _contextQueue = Queue<_PdfGraphicsContext>();

  final PdfGraphicStream _page;

  /// Buffer where to write the graphic operations
  final PdfStream _buf;

  /// Default font if none selected
  PdfFont? get defaultFont => _page.getDefaultFont();

  bool get altered => _page.altered;

  /// Draw a surface on the previously defined shape
  /// set evenOdd to false to use the nonzero winding number rule to determine the region to fill and to true to use the even-odd rule to determine the region to fill
  void fillPath({bool evenOdd = false}) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('f${evenOdd ? '*' : ''} ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('fillPath(evenOdd: $evenOdd)');
      }
      return true;
    }());
  }

  /// Draw the contour of the previously defined shape
  void strokePath({bool close = false}) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('${close ? 's' : 'S'} ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('strokePath(close: $close)');
      }
      return true;
    }());
  }

  /// Close the path with a line
  void closePath() {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('h ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 2 - _indent));
        _buf.putComment('closePath()');
      }
      return true;
    }());
  }

  /// Create a clipping surface from the previously defined shape,
  /// to prevent any further drawing outside
  void clipPath({bool evenOdd = false, bool end = true}) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('W${evenOdd ? '*' : ''}${end ? ' n' : ''} ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('clipPath(evenOdd: $evenOdd, end: $end)');
      }
      return true;
    }());
  }

  /// Draw a surface on the previously defined shape and then draw the contour
  /// set evenOdd to false to use the nonzero winding number rule to determine the region to fill and to true to use the even-odd rule to determine the region to fill
  void fillAndStrokePath({bool evenOdd = false, bool close = false}) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('${close ? 'b' : 'B'}${evenOdd ? '*' : ''} ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('fillAndStrokePath(evenOdd:$evenOdd, close:$close)');
      }
      return true;
    }());
  }

  /// Apply a shader
  void applyShader(PdfShading shader) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    // The shader needs to be registered in the page resources
    _page.addShader(shader);
    _buf.putString('${shader.name} sh ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('applyShader(${shader.ref()})');
      }
      return true;
    }());
  }

  /// This releases any resources used by this Graphics object. You must use
  /// this method once finished with it.
  ///
  /// When using [PdfPage], you can create another fresh Graphics instance,
  /// which will draw over this one.
  void restoreContext() {
    if (_contextQueue.isNotEmpty) {
      assert(() {
        _indent -= _indentAmount;
        if (_page.settings.verbose) {
          _buf.putString(' ' * (_indent));
        }
        return true;
      }());

      // restore graphics context
      _buf.putString('Q ');
      _context = _contextQueue.removeLast();

      assert(() {
        if (_page.settings.verbose) {
          _buf.putString(' ' * (_commentIndent - 2 - _indent));
          _buf.putComment('restoreContext()');
        }
        return true;
      }());
    }
  }

  /// Save the graphic context
  void saveContext() {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());
    _buf.putString('q ');
    _contextQueue.addLast(_context.copy());
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 2 - _indent));
        _buf.putComment('saveContext()');
      }
      _indent += _indentAmount;
      return true;
    }());
  }

  /// Draws an image onto the page.
  void drawImage(PdfImage img, double x, double y, [double? w, double? h]) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    w ??= img.width.toDouble();
    h ??= img.height.toDouble() * w / img.width.toDouble();

    // The image needs to be registered in the page resources
    _page.addXObject(img);

    // q w 0 0 h x y cm % the coordinate matrix
    _buf.putString('q ');
    switch (img.orientation) {
      case PdfImageOrientation.topLeft:
        PdfNumList(<double>[w, 0, 0, h, x, y]).output(_page, _buf);
        break;
      case PdfImageOrientation.topRight:
        PdfNumList(<double>[-w, 0, 0, h, w + x, y]).output(_page, _buf);
        break;
      case PdfImageOrientation.bottomRight:
        PdfNumList(<double>[-w, 0, 0, -h, w + x, h + y]).output(_page, _buf);
        break;
      case PdfImageOrientation.bottomLeft:
        PdfNumList(<double>[w, 0, 0, -h, x, h + y]).output(_page, _buf);
        break;
      case PdfImageOrientation.leftTop:
        PdfNumList(<double>[0, -h, -w, 0, w + x, h + y]).output(_page, _buf);
        break;
      case PdfImageOrientation.rightTop:
        PdfNumList(<double>[0, -h, w, 0, x, h + y]).output(_page, _buf);
        break;
      case PdfImageOrientation.rightBottom:
        PdfNumList(<double>[0, h, w, 0, x, y]).output(_page, _buf);
        break;
      case PdfImageOrientation.leftBottom:
        PdfNumList(<double>[0, h, -w, 0, w + x, y]).output(_page, _buf);
        break;
    }

    _buf.putString(' cm ${img.name} Do Q ');
    _page.altered = true;

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('drawImage(${img.ref()}, x: $x, y: $y, w: $w, h: $h)');
      }
      return true;
    }());
  }

  /// Draws a line between two coordinates.
  void drawLine(double x1, double y1, double x2, double y2) {
    moveTo(x1, y1);
    lineTo(x2, y2);
  }

  /// Draws an ellipse
  ///
  /// Use clockwise=false to draw the inside of a donut
  void drawEllipse(double x, double y, double r1, double r2,
      {bool clockwise = true}) {
    moveTo(x, y - r2);
    if (clockwise) {
      curveTo(x + _m4 * r1, y - r2, x + r1, y - _m4 * r2, x + r1, y);
      curveTo(x + r1, y + _m4 * r2, x + _m4 * r1, y + r2, x, y + r2);
      curveTo(x - _m4 * r1, y + r2, x - r1, y + _m4 * r2, x - r1, y);
      curveTo(x - r1, y - _m4 * r2, x - _m4 * r1, y - r2, x, y - r2);
    } else {
      curveTo(x - _m4 * r1, y - r2, x - r1, y - _m4 * r2, x - r1, y);
      curveTo(x - r1, y + _m4 * r2, x - _m4 * r1, y + r2, x, y + r2);
      curveTo(x + _m4 * r1, y + r2, x + r1, y + _m4 * r2, x + r1, y);
      curveTo(x + r1, y - _m4 * r2, x + _m4 * r1, y - r2, x, y - r2);
    }
  }

  /// Draws a Rectangle
  void drawRect(double x, double y, double w, double h) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNumList([x, y, w, h]).output(_page, _buf);
    _buf.putString(' re ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('drawRect(x: $x, y: $y, w: $w, h: $h)');
      }
      return true;
    }());
  }

  /// Draws a Rectangle
  void drawBox(PdfRect box) {
    drawRect(box.x, box.y, box.width, box.height);
  }

  /// Draws a Rounded Rectangle
  void drawRRect(double x, double y, double w, double h, double rv, double rh) {
    moveTo(x, y + rv);
    curveTo(x, y - _m4 * rv + rv, x - _m4 * rh + rh, y, x + rh, y);
    lineTo(x + w - rh, y);
    curveTo(x + _m4 * rh + w - rh, y, x + w, y - _m4 * rv + rv, x + w, y + rv);
    lineTo(x + w, y + h - rv);
    curveTo(x + w, y + _m4 * rv + h - rv, x + _m4 * rh + w - rh, y + h,
        x + w - rh, y + h);
    lineTo(x + rh, y + h);
    curveTo(x - _m4 * rh + rh, y + h, x, y + _m4 * rv + h - rv, x, y + h - rv);
    lineTo(x, y + rv);
  }

  /// Set the current font and size
  void setFont(
    PdfFont font,
    double size, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double? rise,
  }) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _page.addFont(font);

    _buf.putString('${font.name} ');
    PdfNum(size).output(_page, _buf);
    _buf.putString(' Tf ');
    if (charSpace != null) {
      PdfNum(charSpace).output(_page, _buf);
      _buf.putString(' Tc ');
    }
    if (wordSpace != null) {
      PdfNum(wordSpace).output(_page, _buf);
      _buf.putString(' Tw ');
    }
    if (scale != null) {
      PdfNum(scale * 100).output(_page, _buf);
      _buf.putString(' Tz ');
    }
    if (rise != null) {
      PdfNum(rise).output(_page, _buf);
      _buf.putString(' Ts ');
    }
    if (mode != PdfTextRenderingMode.fill) {
      _buf.putString('${mode.index} Tr ');
    }

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment(
            'setFont(${font.ref()}, size: $size, charSpace: $charSpace, wordSpace: $wordSpace, scale: $scale, mode: ${mode.name}, rise: $rise)');
      }
      return true;
    }());
  }

  /// This draws a string.
  void drawString(
    PdfFont font,
    double size,
    String s,
    double x,
    double y, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double? rise,
  }) {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    // Filter out zero-width spaces (0x200b)
    s = String.fromCharCodes(s.runes.where((r) => r!=0x200b));

    _buf.putString('BT ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 3 - _indent));
        _buf.putComment('beginText()');
        _indent += _indentAmount;
      }
      return true;
    }());

    setFont(font, size,
        charSpace: charSpace,
        mode: mode,
        rise: rise,
        scale: scale,
        wordSpace: wordSpace);

    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNumList([x, y]).output(_page, _buf);
    _buf.putString(' Td ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('moveCursor($x, $y)');
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('[');
    font.putText(_buf, s);
    _buf.putString(']TJ ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('drawString("$s")');
        o = _buf.offset;
        _indent -= _indentAmount;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('ET ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 3 - _indent));
        _buf.putComment('endText()');
      }
      return true;
    }());

    _page.altered = true;
  }


  void drawGlyphs(
    PdfFont font,
    double size,
    List<int> glyphIndices,
    double x,
    double y, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double? rise,
  }) {
    _buf.putString('BT ');

    setFont(font, size,
        charSpace: charSpace,
        mode: mode,
        rise: rise,
        scale: scale,
        wordSpace: wordSpace);

    PdfNumList([x, y]).output(_page, _buf);
    _buf.putString(' Td ');

    _buf.putString('[');
    font.putGlyphs(_buf, glyphIndices);
    _buf.putString(']TJ ');

    _buf.putString('ET ');

    _page.altered = true;
  }



  void reset() {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('0 Tr ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 5 - _indent));
        _buf.putComment('reset()');
      }
      return true;
    }());
  }

  /// Sets the color for drawing
  void setColor(PdfColor? color) {
    setFillColor(color);
    setStrokeColor(color);
  }

  /// Sets the fill color for drawing
  void setFillColor(PdfColor? color) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    if (color is PdfColorCmyk) {
      PdfNumList(<double>[color.cyan, color.magenta, color.yellow, color.black])
          .output(_page, _buf);
      _buf.putString(' k ');
    } else {
      PdfNumList(<double>[color!.red, color.green, color.blue])
          .output(_page, _buf);
      _buf.putString(' rg ');
    }

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setFillColor(${color?.toHex()})');
      }
      return true;
    }());
  }

  /// Sets the stroke color for drawing
  void setStrokeColor(PdfColor? color) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    if (color is PdfColorCmyk) {
      PdfNumList(<double>[color.cyan, color.magenta, color.yellow, color.black])
          .output(_page, _buf);
      _buf.putString(' K ');
    } else {
      PdfNumList(<double>[color!.red, color.green, color.blue])
          .output(_page, _buf);
      _buf.putString(' RG ');
    }

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setStrokeColor(${color?.toHex()})');
      }
      return true;
    }());
  }

  /// Sets the fill pattern for drawing
  void setFillPattern(PdfPattern pattern) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    // The shader needs to be registered in the page resources
    _page.addPattern(pattern);
    _buf.putString('/Pattern cs${pattern.name} scn ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setFillPattern(${pattern.ref()})');
      }
      return true;
    }());
  }

  /// Sets the stroke pattern for drawing
  void setStrokePattern(PdfPattern pattern) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    // The shader needs to be registered in the page resources
    _page.addPattern(pattern);
    _buf.putString('/Pattern CS${pattern.name} SCN ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setStrokePattern(${pattern.ref()})');
      }
      return true;
    }());
  }

  /// Set the graphic state for drawing
  void setGraphicState(PdfGraphicState state) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    final name = _page.stateName(state);
    _buf.putString('$name gs ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setGraphicState($state)');
      }
      return true;
    }());
  }

  /// Set the transformation Matrix
  void setTransform(Matrix4 t) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    final s = t.storage;
    PdfNumList(<double>[s[0], s[1], s[4], s[5], s[12], s[13]])
        .output(_page, _buf);
    _buf.putString(' cm ');
    _context.ctm.multiply(t);

    assert(() {
      if (_page.settings.verbose) {
        final n = math.max(0, _commentIndent - _buf.offset + o);
        _buf.putString(' ' * n);
        _buf.putComment('setTransform($s)');
      }
      return true;
    }());
  }

  /// Get the transformation Matrix
  Matrix4 getTransform() {
    return _context.ctm.clone();
  }

  /// This adds a line segment to the current path
  void lineTo(double x, double y) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNumList([x, y]).output(_page, _buf);
    _buf.putString(' l ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('lineTo($x, $y)');
      }
      return true;
    }());
  }

  /// This moves the current drawing point.
  void moveTo(double x, double y) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNumList([x, y]).output(_page, _buf);
    _buf.putString(' m ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('moveTo($x, $y)');
      }
      return true;
    }());
  }

  /// Draw a cubic bézier curve from the current point to (x3,y3)
  /// using (x1,y1) as the control point at the beginning of the curve
  /// and (x2,y2) as the control point at the end of the curve.
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNumList([x1, y1, x2, y2, x3, y3]).output(_page, _buf);
    _buf.putString(' c ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('curveTo($x1, $y1, $x2, $y2, $x3, $y3)');
      }
      return true;
    }());
  }

  double _vectorAngle(double ux, double uy, double vx, double vy) {
    final d = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    if (d == 0.0) {
      return 0;
    }
    var c = (ux * vx + uy * vy) / d;
    if (c < -1.0) {
      c = -1.0;
    } else if (c > 1.0) {
      c = 1.0;
    }
    final s = ux * vy - uy * vx;
    c = math.acos(c);
    return c.sign == s.sign ? c : -c;
  }

  void _endToCenterParameters(double x1, double y1, double x2, double y2,
      bool large, bool sweep, double rx, double ry) {
    // See http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes F.6.5

    rx = rx.abs();
    ry = ry.abs();

    final x1d = 0.5 * (x1 - x2);
    final y1d = 0.5 * (y1 - y2);

    var r = x1d * x1d / (rx * rx) + y1d * y1d / (ry * ry);
    if (r > 1.0) {
      final rr = math.sqrt(r);
      rx *= rr;
      ry *= rr;
      r = x1d * x1d / (rx * rx) + y1d * y1d / (ry * ry);
    } else if (r != 0.0) {
      r = 1.0 / r - 1.0;
    }

    if (-1e-10 < r && r < 0.0) {
      r = 0.0;
    }

    r = math.sqrt(r);
    if (large == sweep) {
      r = -r;
    }

    final cxd = (r * rx * y1d) / ry;
    final cyd = -(r * ry * x1d) / rx;

    final cx = cxd + 0.5 * (x1 + x2);
    final cy = cyd + 0.5 * (y1 + y2);

    final theta = _vectorAngle(1, 0, (x1d - cxd) / rx, (y1d - cyd) / ry);
    var dTheta = _vectorAngle((x1d - cxd) / rx, (y1d - cyd) / ry,
            (-x1d - cxd) / rx, (-y1d - cyd) / ry) %
        (math.pi * 2.0);
    if (sweep == false && dTheta > 0.0) {
      dTheta -= math.pi * 2.0;
    } else if (sweep == true && dTheta < 0.0) {
      dTheta += math.pi * 2.0;
    }
    _bezierArcFromCentre(cx, cy, rx, ry, -theta, -dTheta);
  }

  void _bezierArcFromCentre(double cx, double cy, double rx, double ry,
      double startAngle, double extent) {
    int fragmentsCount;
    double fragmentsAngle;

    if (extent.abs() <= math.pi / 2.0) {
      fragmentsCount = 1;
      fragmentsAngle = extent;
    } else {
      fragmentsCount = (extent.abs() / (math.pi / 2.0)).ceil().toInt();
      fragmentsAngle = extent / fragmentsCount.toDouble();
    }
    if (fragmentsAngle == 0.0) {
      return;
    }

    final halfFragment = fragmentsAngle * 0.5;
    var kappa =
        (4.0 / 3.0 * (1.0 - math.cos(halfFragment)) / math.sin(halfFragment))
            .abs();

    if (fragmentsAngle < 0.0) {
      kappa = -kappa;
    }

    var theta = startAngle;
    final startFragment = theta + fragmentsAngle;

    var c1 = math.cos(theta);
    var s1 = math.sin(theta);
    for (var i = 0; i < fragmentsCount; i++) {
      final c0 = c1;
      final s0 = s1;
      theta = startFragment + i * fragmentsAngle;
      c1 = math.cos(theta);
      s1 = math.sin(theta);
      curveTo(
          cx + rx * (c0 - kappa * s0),
          cy - ry * (s0 + kappa * c0),
          cx + rx * (c1 + kappa * s1),
          cy - ry * (s1 - kappa * c1),
          cx + rx * c1,
          cy - ry * s1);
    }
  }

  /// Draws an elliptical arc from (x1, y1) to (x2, y2).
  /// The size and orientation of the ellipse are defined by two radii (rx, ry)
  /// The center (cx, cy) of the ellipse is calculated automatically to satisfy
  /// the constraints imposed by the other parameters. large and sweep flags
  /// contribute to the automatic calculations and help determine how the arc is drawn.
  void bezierArc(
      double x1, double y1, double rx, double ry, double x2, double y2,
      {bool large = false, bool sweep = false, double phi = 0.0}) {
    if (x1 == x2 && y1 == y2) {
      // From https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes:
      // If the endpoints (x1, y1) and (x2, y2) are identical, then this is
      // equivalent to omitting the elliptical arc segment entirely.
      return;
    }

    if (rx.abs() <= 1e-10 || ry.abs() <= 1e-10) {
      lineTo(x2, y2);
      return;
    }

    if (phi != 0.0) {
      // Our box bézier arcs can't handle rotations directly
      // move to a well known point, eliminate phi and transform the other point
      final mat = Matrix4.identity();
      mat.translate(-x1, -y1);
      mat.rotateZ(-phi);
      final tr = mat.transform3(Vector3(x2, y2, 0));
      _endToCenterParameters(0, 0, tr[0], tr[1], large, sweep, rx, ry);
    } else {
      _endToCenterParameters(x1, y1, x2, y2, large, sweep, rx, ry);
    }
  }

  /// Draw an SVG path
  void drawShape(String d) {
    final proxy = _PathProxy(this);
    try {
      writeSvgPathDataToPath(d, proxy);
    } catch (e, s) {
      print('[pdf][PdfGraphics.drawShape] Error writing SVG shape $d: $e\n$s');
    }
  }

  /// Calculates the bounding box of an SVG path
  static PdfRect shapeBoundingBox(String d) {
    final proxy = _PathBBProxy();
    try {
      writeSvgPathDataToPath(d, proxy);
    } catch (e, s) {
      print('[pdf][PdfGraphics.shapeBoundingBox] Error writing SVG shape $d: $e\n$s');
    }
    return proxy.box;
  }

  /// Set line starting and ending cap type
  void setLineCap(PdfLineCap cap) {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('${cap.index} J ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 4 - _indent));
        _buf.putComment('setLineCap(${cap.name})');
      }
      return true;
    }());
  }

  /// Set line join type
  void setLineJoin(PdfLineJoin join) {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('${join.index} j ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 4 - _indent));
        _buf.putComment('setLineJoin(${join.name})');
      }
      return true;
    }());
  }

  /// Set line width
  void setLineWidth(double width) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfNum(width).output(_page, _buf);
    _buf.putString(' w ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setLineWidth($width)');
      }
      return true;
    }());
  }

  /// Set line joint miter limit, applies if the
  void setMiterLimit(double limit) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    assert(limit >= 1.0);
    PdfNum(limit).output(_page, _buf);
    _buf.putString(' M ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setMiterLimit($limit)');
      }
      return true;
    }());
  }

  /// The dash array shall be cycled through, adding up the lengths of dashes and gaps.
  /// When the accumulated length equals the value specified by the dash phase
  ///
  /// Example: [2 1] will create a dash pattern with 2 on, 1 off, 2 on, 1 off, ...
  void setLineDashPattern([List<num> array = const <num>[], int phase = 0]) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    PdfArray.fromNum(array).output(_page, _buf);
    _buf.putString(' $phase d ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('setLineDashPattern($array, $phase)');
      }
      return true;
    }());
  }

  void markContentBegin(PdfName tag) {
    var o = 0;
    assert(() {
      if (_page.settings.verbose) {
        o = _buf.offset;
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    tag.output(_page, _buf);
    _buf.putString(' BMC ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * math.max(0, _commentIndent - _buf.offset + o));
        _buf.putComment('markContentBegin($tag)');
      }
      return true;
    }());
  }

  void markContentEnd() {
    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_indent));
      }
      return true;
    }());

    _buf.putString('EMC ');

    assert(() {
      if (_page.settings.verbose) {
        _buf.putString(' ' * (_commentIndent - 4 - _indent));
        _buf.putComment('markContentEnd()');
      }
      return true;
    }());
  }
}

class _PathProxy extends PathProxy {
  _PathProxy(this.canvas);

  final PdfGraphics canvas;

  @override
  void close() {
    canvas.closePath();
  }

  @override
  void cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    canvas.curveTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void lineTo(double x, double y) {
    canvas.lineTo(x, y);
  }

  @override
  void moveTo(double x, double y) {
    canvas.moveTo(x, y);
  }
}

class _PathBBProxy extends PathProxy {
  _PathBBProxy();

  var _xMin = double.infinity;
  var _yMin = double.infinity;
  var _xMax = double.negativeInfinity;
  var _yMax = double.negativeInfinity;

  var _pX = 0.0;
  var _pY = 0.0;

  PdfRect get box {
    if (_xMin > _xMax || _yMin > _yMax) {
      return PdfRect.zero;
    }
    return PdfRect.fromLTRB(_xMin, _yMin, _xMax, _yMax);
  }

  @override
  void close() {}

  @override
  void cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    final tValues = <double>[];
    double a, b, c, t, t1, t2, b2ac, sqrtB2ac;

    for (var i = 0; i < 2; ++i) {
      if (i == 0) {
        b = 6 * _pX - 12 * x1 + 6 * x2;
        a = -3 * _pX + 9 * x1 - 9 * x2 + 3 * x3;
        c = 3 * x1 - 3 * _pX;
      } else {
        b = 6 * _pY - 12 * y1 + 6 * y2;
        a = -3 * _pY + 9 * y1 - 9 * y2 + 3 * y3;
        c = 3 * y1 - 3 * _pY;
      }
      if (a.abs() < 1e-12) {
        if (b.abs() < 1e-12) {
          continue;
        }
        t = -c / b;
        if (0 < t && t < 1) {
          tValues.add(t);
        }
        continue;
      }
      b2ac = b * b - 4 * c * a;
      if (b2ac < 0) {
        if (b2ac.abs() < 1e-12) {
          t = -b / (2 * a);
          if (0 < t && t < 1) {
            tValues.add(t);
          }
        }
        continue;
      }
      sqrtB2ac = math.sqrt(b2ac);
      t1 = (-b + sqrtB2ac) / (2 * a);
      if (0 < t1 && t1 < 1) {
        tValues.add(t1);
      }
      t2 = (-b - sqrtB2ac) / (2 * a);
      if (0 < t2 && t2 < 1) {
        tValues.add(t2);
      }
    }

    for (final t in tValues) {
      final mt = 1 - t;
      _updateMinMax(
          (mt * mt * mt * _pX) +
              (3 * mt * mt * t * x1) +
              (3 * mt * t * t * x2) +
              (t * t * t * x3),
          (mt * mt * mt * _pY) +
              (3 * mt * mt * t * y1) +
              (3 * mt * t * t * y2) +
              (t * t * t * y3));
    }
    _updateMinMax(_pX, _pY);
    _updateMinMax(x3, y3);

    _pX = x3;
    _pY = y3;
  }

  @override
  void lineTo(double x, double y) {
    _pX = x;
    _pY = y;
    _updateMinMax(x, y);
  }

  @override
  void moveTo(double x, double y) {
    _pX = x;
    _pY = y;
    _updateMinMax(x, y);
  }

  void _updateMinMax(double x, double y) {
    _xMin = math.min(_xMin, x);
    _yMin = math.min(_yMin, y);
    _xMax = math.max(_xMax, x);
    _yMax = math.max(_yMax, y);
  }
}
