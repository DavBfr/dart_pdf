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

// ignore_for_file: omit_local_variable_types

part of pdf;

enum PdfLineCap { joinMiter, joinRound, joinBevel }

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
  const _PdfGraphicsContext({@required this.ctm}) : assert(ctm != null);
  final Matrix4 ctm;

  _PdfGraphicsContext copy() => _PdfGraphicsContext(ctm: ctm.clone());
}

class PdfGraphics {
  PdfGraphics(this.page, this.buf) {
    _context = _PdfGraphicsContext(ctm: Matrix4.identity());
  }

  /// Ellipse 4-spline magic number
  static const double _m4 = 0.551784;

  /// Graphic context
  _PdfGraphicsContext _context;
  final Queue<_PdfGraphicsContext> _contextQueue = Queue<_PdfGraphicsContext>();

  final PdfPage page;

  final PdfStream buf;

  PdfFont get defaultFont {
    if (page.pdfDocument.fonts.isEmpty) {
      PdfFont.helvetica(page.pdfDocument);
    }

    return page.pdfDocument.fonts.elementAt(0);
  }

  void fillPath() {
    buf.putString('f\n');
  }

  void strokePath() {
    buf.putString('S\n');
  }

  void closePath() {
    buf.putString('s\n');
  }

  void clipPath() {
    buf.putString('W n\n');
  }

  /// This releases any resources used by this Graphics object. You must use
  /// this method once finished with it.
  ///
  /// When using [PdfPage], you can create another fresh Graphics instance,
  /// which will draw over this one.
  void restoreContext() {
    if (_contextQueue.isNotEmpty) {
      // restore graphics context
      buf.putString('Q\n');
      _context = _contextQueue.removeLast();
    }
  }

  void saveContext() {
    // save graphics context
    buf.putString('q\n');
    _contextQueue.addLast(_context.copy());
  }

  /// Draws an image onto the page.
  ///
  /// This method is implemented with [Ascii85Encoder] encoding and the
  /// zip stream deflater.  It results in a stream that is anywhere
  /// from 3 to 10 times as big as the image.  This obviously needs some
  /// improvement, but it works well for small images
  ///
  /// @param img The Image
  /// @param x   coordinate on page
  /// @param y   coordinate on page
  /// @param w   Width on page
  /// @param h   height on page
  /// @param bgcolor Background colour
  /// @return true if drawn
  void drawImage(PdfImage img, double x, double y, [double w, double h]) {
    w ??= img.width.toDouble();
    h ??= img.height.toDouble() * w / img.width.toDouble();

    // The image needs to be registered in the page resources
    page.xObjects[img.name] = img;

    // q w 0 0 h x y cm % the coordinate matrix
    buf.putString('q ');
    switch (img.orientation) {
      case PdfImageOrientation.topLeft:
        buf.putNumList(<double>[w, 0, 0, h, x, y]);
        break;
      case PdfImageOrientation.topRight:
        buf.putNumList(<double>[-w, 0, 0, h, w + x, y]);
        break;
      case PdfImageOrientation.bottomRight:
        buf.putNumList(<double>[-w, 0, 0, -h, w + x, h + y]);
        break;
      case PdfImageOrientation.bottomLeft:
        buf.putNumList(<double>[w, 0, 0, -h, x, h + y]);
        break;
      case PdfImageOrientation.leftTop:
        buf.putNumList(<double>[0, -h, -w, 0, w + x, h + y]);
        break;
      case PdfImageOrientation.rightTop:
        buf.putNumList(<double>[0, -h, w, 0, x, h + y]);
        break;
      case PdfImageOrientation.rightBottom:
        buf.putNumList(<double>[0, h, w, 0, x, y]);
        break;
      case PdfImageOrientation.leftBottom:
        buf.putNumList(<double>[0, h, -w, 0, w + x, y]);
        break;
    }

    buf.putString(' cm ${img.name} Do Q\n');
  }

  /// Draws a line between two coordinates.
  ///
  /// If the first coordinate is the same as the last one drawn
  /// (i.e. a previous drawLine, moveto, etc) it is ignored.
  ///
  /// @param x1 coordinate
  /// @param y1 coordinate
  /// @param x2 coordinate
  /// @param y2 coordinate
  void drawLine(double x1, double y1, double x2, double y2) {
    moveTo(x1, y1);
    lineTo(x2, y2);
  }

  /// Draws a polygon, linking the first and last coordinates.
  ///
  /// @param xp Array of x coordinates
  /// @param yp Array of y coordinates
  /// @param np number of points in polygon
  void drawPolygon(PdfPolygon p) {
    _polygon(p.points);
  }

  void drawEllipse(double x, double y, double r1, double r2) {
    moveTo(x, y - r2);
    curveTo(x + _m4 * r1, y - r2, x + r1, y - _m4 * r2, x + r1, y);
    curveTo(x + r1, y + _m4 * r2, x + _m4 * r1, y + r2, x, y + r2);
    curveTo(x - _m4 * r1, y + r2, x - r1, y + _m4 * r2, x - r1, y);
    curveTo(x - r1, y - _m4 * r2, x - _m4 * r1, y - r2, x, y - r2);
  }

  /// Draws a Rectangle
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @param w width
  /// @param h height
  void drawRect(
    double x,
    double y,
    double w,
    double h,
  ) {
    buf.putNumList(<double>[x, y, w, h]);
    buf.putString(' re\n');
  }

  /// Draws a Rounded Rectangle
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @param w width
  /// @param h height
  /// @param rh horizontal radius
  /// @param rv vertical radius
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

  /// This draws a string.
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @param s String to draw
  void drawString(
    PdfFont font,
    double size,
    String s,
    double x,
    double y, {
    double charSpace = 0,
    double wordSpace = 0,
    double scale = 1,
    PdfTextRenderingMode mode = PdfTextRenderingMode.fill,
    double rise = 0,
  }) {
    if (!page.fonts.containsKey(font.name)) {
      page.fonts[font.name] = font;
    }

    buf.putString('BT ');
    buf.putNumList(<double>[x, y]);
    buf.putString(' Td ${font.name} ');
    buf.putNum(size);
    buf.putString(' Tf ');
    if (charSpace != 0) {
      buf.putNum(charSpace);
      buf.putString(' Tc ');
    }
    if (wordSpace != 0) {
      buf.putNum(wordSpace);
      buf.putString(' Tw ');
    }
    if (scale != 1) {
      buf.putNum(scale * 100);
      buf.putString(' Tz ');
    }
    if (rise != 0) {
      buf.putNum(rise);
      buf.putString(' Ts ');
    }
    if (mode != PdfTextRenderingMode.fill) {
      buf.putString('${mode.index} Tr ');
    }
    buf.putString('[');
    font.putText(buf, s);
    buf.putString(']TJ ET\n');
  }

  /// Sets the color for drawing
  ///
  /// @param c Color to use
  void setColor(PdfColor color) {
    setFillColor(color);
    setStrokeColor(color);
  }

  /// Sets the fill color for drawing
  ///
  /// @param c Color to use
  void setFillColor(PdfColor color) {
    if (color is PdfColorCmyk) {
      buf.putNumList(
          <double>[color.cyan, color.magenta, color.yellow, color.black]);
      buf.putString(' k\n');
    } else {
      buf.putNumList(<double>[color.red, color.green, color.blue]);
      buf.putString(' rg\n');
    }
  }

  /// Sets the stroke color for drawing
  ///
  /// @param c Color to use
  void setStrokeColor(PdfColor color) {
    if (color is PdfColorCmyk) {
      buf.putNumList(
          <double>[color.cyan, color.magenta, color.yellow, color.black]);
      buf.putString(' K\n');
    } else {
      buf.putNumList(<double>[color.red, color.green, color.blue]);
      buf.putString(' RG\n');
    }
  }

  /// Set the graphic state for drawing
  void setGraphicState(PdfGraphicState state) {
    final String name = page.pdfDocument.graphicStates.stateName(state);
    buf.putString('$name gs\n');
  }

  /// Set the transformation Matrix
  void setTransform(Matrix4 t) {
    final Float64List s = t.storage;
    buf.putNumList(<double>[s[0], s[1], s[4], s[5], s[12], s[13]]);
    buf.putString(' cm\n');
    _context.ctm.multiply(t);
  }

  /// Get the transformation Matrix
  Matrix4 getTransform() {
    return _context.ctm.clone();
  }

  /// This adds a line segment to the current path
  ///
  /// @param x coordinate
  /// @param y coordinate
  void lineTo(double x, double y) {
    buf.putNumList(<double>[x, y]);
    buf.putString(' l\n');
  }

  /// This moves the current drawing point.
  ///
  /// @param x coordinate
  /// @param y coordinate
  void moveTo(double x, double y) {
    buf.putNumList(<double>[x, y]);
    buf.putString(' m\n');
  }

  /// Draw a cubic bézier curve from the current point to (x3,y3)
  /// using (x1,y1) as the control point at the beginning of the curve
  /// and (x2,y2) as the control point at the end of the curve.
  ///
  /// @param x1 first control point
  /// @param y1 first control point
  /// @param x2 second control point
  /// @param y2 second control point
  /// @param x3 end point
  /// @param y3 end point
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    buf.putNumList(<double>[x1, y1, x2, y2, x3, y3]);
    buf.putString(' c\n');
  }

  double _vectorAngle(double ux, double uy, double vx, double vy) {
    final double d =
        math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    if (d == 0.0) {
      return 0;
    }
    double c = (ux * vx + uy * vy) / d;
    if (c < -1.0) {
      c = -1.0;
    } else if (c > 1.0) {
      c = 1.0;
    }
    final double s = ux * vy - uy * vx;
    c = math.acos(c);
    return c.sign == s.sign ? c : -c;
  }

  void _endToCenterParameters(double x1, double y1, double x2, double y2,
      bool large, bool sweep, double rx, double ry) {
    // See http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes F.6.5

    rx = rx.abs();
    ry = ry.abs();

    final double x1d = 0.5 * (x1 - x2);
    final double y1d = 0.5 * (y1 - y2);

    double r = x1d * x1d / (rx * rx) + y1d * y1d / (ry * ry);
    if (r > 1.0) {
      final double rr = math.sqrt(r);
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

    final double cxd = (r * rx * y1d) / ry;
    final double cyd = -(r * ry * x1d) / rx;

    final double cx = cxd + 0.5 * (x1 + x2);
    final double cy = cyd + 0.5 * (y1 + y2);

    final double theta = _vectorAngle(1, 0, (x1d - cxd) / rx, (y1d - cyd) / ry);
    double dTheta = _vectorAngle((x1d - cxd) / rx, (y1d - cyd) / ry,
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

    final double halfFragment = fragmentsAngle * 0.5;
    double kappa =
        (4.0 / 3.0 * (1.0 - math.cos(halfFragment)) / math.sin(halfFragment))
            .abs();

    if (fragmentsAngle < 0.0) {
      kappa = -kappa;
    }

    double theta = startAngle;
    final double startFragment = theta + fragmentsAngle;

    double c1 = math.cos(theta);
    double s1 = math.sin(theta);
    for (int i = 0; i < fragmentsCount; i++) {
      final double c0 = c1;
      final double s0 = s1;
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
      final Matrix4 mat = Matrix4.identity();
      mat.translate(-x1, -y1);
      mat.rotateZ(-phi);
      final Vector3 tr = mat.transform3(Vector3(x2, y2, 0));
      _endToCenterParameters(0, 0, tr[0], tr[1], large, sweep, rx, ry);
    } else {
      _endToCenterParameters(x1, y1, x2, y2, large, sweep, rx, ry);
    }
  }

  /// https://github.com/deeplook/svglib/blob/master/svglib/svglib.py#L911
  void drawShape(String d, {bool stroke = true}) {
    final RegExp exp =
        RegExp(r'([MmZzLlHhVvCcSsQqTtAaE])|(-[\.0-9]+)|([\.0-9]+)');
    final Iterable<Match> matches = exp.allMatches(d + ' E');
    String action;
    String lastAction;
    List<double> points;
    PdfPoint lastControl = const PdfPoint(0, 0);
    PdfPoint lastPoint = const PdfPoint(0, 0);
    for (Match m in matches) {
      final String a = m.group(1);
      final String b = m.group(0);

      if (a == null) {
        points.add(double.parse(b));
        continue;
      }

      if (action != null) {
        switch (action) {
          case 'm': // moveto relative
            lastPoint =
                PdfPoint(lastPoint.x + points[0], lastPoint.y + points[1]);
            moveTo(lastPoint.x, lastPoint.y);
            break;
          case 'M': // moveto absolute
            lastPoint = PdfPoint(points[0], points[1]);
            moveTo(lastPoint.x, lastPoint.y);
            break;
          case 'l': // lineto relative
            lastPoint =
                PdfPoint(lastPoint.x + points[0], lastPoint.y + points[1]);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'L': // lineto absolute
            lastPoint = PdfPoint(points[0], points[1]);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'H': // horizontal line absolute
            lastPoint = PdfPoint(points[0], lastPoint.y);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'V': // vertical line absolute
            lastPoint = PdfPoint(lastPoint.x, points[0]);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'h': // horizontal line relative
            lastPoint = PdfPoint(lastPoint.x + points[0], lastPoint.y);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'v': // vertical line relative
            lastPoint = PdfPoint(lastPoint.x, lastPoint.y + points[0]);
            lineTo(lastPoint.x, lastPoint.y);
            break;
          case 'C': // cubic bezier, absolute
            int len = 0;
            while (len < points.length) {
              curveTo(points[len + 0], points[len + 1], points[len + 2],
                  points[len + 3], points[len + 4], points[len + 5]);
              len += 6;
            }
            lastPoint =
                PdfPoint(points[points.length - 2], points[points.length - 1]);
            lastControl =
                PdfPoint(points[points.length - 4], points[points.length - 3]);
            break;
          case 'S': // smooth cubic bézier, absolute
            while (points.length >= 4) {
              PdfPoint c1;
              if ('cCsS'.contains(lastAction)) {
                c1 = PdfPoint(lastPoint.x + (lastPoint.x - lastControl.x),
                    lastPoint.y + (lastPoint.y - lastControl.y));
              } else {
                c1 = lastPoint;
              }
              lastControl = PdfPoint(points[0], points[1]);
              lastPoint = PdfPoint(points[2], points[3]);
              curveTo(c1.x, c1.y, lastControl.x, lastControl.y, lastPoint.x,
                  lastPoint.y);
              points = points.sublist(4);
              lastAction = 'C';
            }
            break;
          case 'c': // cubic bezier, relative
            int len = 0;
            while (len < points.length) {
              points[len + 0] += lastPoint.x;
              points[len + 1] += lastPoint.y;
              points[len + 2] += lastPoint.x;
              points[len + 3] += lastPoint.y;
              points[len + 4] += lastPoint.x;
              points[len + 5] += lastPoint.y;
              curveTo(points[len + 0], points[len + 1], points[len + 2],
                  points[len + 3], points[len + 4], points[len + 5]);
              lastPoint = PdfPoint(points[len + 4], points[len + 5]);
              lastControl = PdfPoint(points[len + 2], points[len + 3]);
              len += 6;
            }
            break;
          case 's': // smooth cubic bézier, relative
            while (points.length >= 4) {
              PdfPoint c1;
              if ('cCsS'.contains(lastAction)) {
                c1 = PdfPoint(lastPoint.x + (lastPoint.x - lastControl.x),
                    lastPoint.y + (lastPoint.y - lastControl.y));
              } else {
                c1 = lastPoint;
              }
              lastControl =
                  PdfPoint(points[0] + lastPoint.x, points[1] + lastPoint.y);
              lastPoint =
                  PdfPoint(points[2] + lastPoint.x, points[3] + lastPoint.y);
              curveTo(c1.x, c1.y, lastControl.x, lastControl.y, lastPoint.x,
                  lastPoint.y);
              points = points.sublist(4);
              lastAction = 'c';
            }
            break;
          // case 'Q': // quadratic bezier, absolute
          //   break;
          // case 'T': // quadratic bezier, absolute
          //   break;
          // case 'q': // quadratic bezier, relative
          //   break;
          // case 't': // quadratic bezier, relative
          //   break;
          case 'A': // elliptical arc, absolute
            int len = 0;
            while (len < points.length) {
              bezierArc(lastPoint.x, lastPoint.y, points[len + 0],
                  points[len + 1], points[len + 5], points[len + 6],
                  phi: points[len + 2] * math.pi / 180.0,
                  large: points[len + 3] != 0.0,
                  sweep: points[len + 4] != 0.0);
              lastPoint = PdfPoint(points[len + 5], points[len + 6]);
              len += 7;
            }
            break;
          case 'a': // elliptical arc, relative
            int len = 0;
            while (len < points.length) {
              points[len + 5] += lastPoint.x;
              points[len + 6] += lastPoint.y;
              bezierArc(lastPoint.x, lastPoint.y, points[len + 0],
                  points[len + 1], points[len + 5], points[len + 6],
                  phi: points[len + 2] * math.pi / 180.0,
                  large: points[len + 3] != 0.0,
                  sweep: points[len + 4] != 0.0);
              lastPoint = PdfPoint(points[len + 5], points[len + 6]);
              len += 7;
            }
            break;
          case 'Z': // close path
          case 'z': // close path
            if (stroke) {
              closePath();
            }
            break;
          default:
            print('Unknown path action: $action');
        }
      }
      lastAction = action;
      action = a;
      points = <double>[];
    }
  }

  /// This is used to add a polygon to the current path.
  /// Used by drawPolygon()
  ///
  /// @param p Array of coordinates
  /// @see #drawPolygon
  /// @see #drawPolyline
  /// @see #fillPolygon
  void _polygon(List<PdfPoint> p) {
    // newPath() not needed here as moveto does it ;-)
    moveTo(p[0].x, p[0].y);

    for (int i = 1; i < p.length; i++) {
      lineTo(p[i].x, p[i].y);
    }
  }

  void setLineCap(PdfLineCap cap) {
    buf.putString('${cap.index} J\n');
  }

  void setLineJoin(PdfLineCap join) {
    buf.putString('${join.index} j\n');
  }

  void setLineWidth(double width) {
    buf.putNum(width);
    buf.putString(' w\n');
  }

  void setMiterLimit(double limit) {
    buf.putNum(limit);
    buf.putString(' M\n');
  }
}
