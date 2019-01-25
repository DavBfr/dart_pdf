/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

enum PdfLineCap { joinMiter, joinRound, joinBevel }

class PdfGraphics {
  /// Graphic context number
  var _context = 0;

  final PdfPage page;

  final PdfStream buf;

  PdfGraphics(this.page, this.buf);

  PdfFont get defaultFont {
    if (page.pdfDocument.fonts.length == 0) {
      PdfFont.helvetica(page.pdfDocument);
    }

    return page.pdfDocument.fonts.elementAt(0);
  }

  void fillPath() {
    buf.putString("f\n");
  }

  void strokePath() {
    buf.putString("S\n");
  }

  void closePath() {
    buf.putString("s\n");
  }

  void clipPath() {
    buf.putString("W n\n");
  }

  /// This releases any resources used by this Graphics object. You must use
  /// this method once finished with it.
  ///
  /// When using [PdfPage], you can create another fresh Graphics instance,
  /// which will draw over this one.
  void restoreContext() {
    if (_context > 0) {
      // restore graphics context
      buf.putString("Q\n");
      _context--;
    }
  }

  void saveContext() {
    // save graphics context
    buf.putString("q\n");
    _context++;
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
    if (w == null) w = img.width.toDouble();
    if (h == null) h = img.height.toDouble() * w / img.width.toDouble();

    // The image needs to be registered in the page resources
    page.xObjects[img.name] = img;

    // q w 0 0 h x y cm % the coordinate matrix
    buf.putString("q ");
    buf.putNumList(<double>[w, 0.0, 0.0, h, x, y]);
    buf.putString(" cm ${img.name} Do Q\n");
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
    // The best 4-spline magic number
    double m4 = 0.551784;

    // Starting point
    moveTo(x, y - r2);

    buf.putNumList(
        <double>[x + m4 * r1, y - r2, x + r1, y - m4 * r2, x + r1, y]);
    buf.putString(" c\n");
    buf.putNumList(
        <double>[x + r1, y + m4 * r2, x + m4 * r1, y + r2, x, y + r2]);
    buf.putString(" c\n");
    buf.putNumList(
        <double>[x - m4 * r1, y + r2, x - r1, y + m4 * r2, x - r1, y]);
    buf.putString(" c\n");
    buf.putNumList(
        <double>[x - r1, y - m4 * r2, x - m4 * r1, y - r2, x, y - r2]);
    buf.putString(" c\n");
  }

  /// We override Graphics.drawRect as it doesn't join the 4 lines.
  /// Also, Pdf provides us with a Rectangle operator, so we will use that.
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
    buf.putString(" re\n");
  }

  /// This draws a string.
  ///
  /// @param x coordinate
  /// @param y coordinate
  /// @oaran s String to draw
  void drawString(PdfFont font, double size, String s, double x, double y) {
    if (!page.fonts.containsKey(font.name)) {
      page.fonts[font.name] = font;
    }

    buf.putString("BT ");
    buf.putNumList(<double>[x, y]);
    buf.putString(" Td ${font.name} ");
    buf.putNum(size);
    buf.putString(" Tf ");
    buf.putText(s);
    buf.putString(" Tj ET\n");
  }

  /// Sets the color for drawing
  ///
  /// @param c Color to use
  void setColor(PdfColor color) {
    buf.putNumList(<double>[color.r, color.g, color.b]);
    buf.putString(" rg ");
    buf.putNumList(<double>[color.r, color.g, color.b]);
    buf.putString(" RG\n");
  }

  /// Set the transformation Matrix
  void setTransform(Matrix4 t) {
    var s = t.storage;
    buf.putNumList(<double>[s[0], s[1], s[4], s[5], s[12], s[13]]);
    buf.putString(" cm\n");
  }

  /// This adds a line segment to the current path
  ///
  /// @param x coordinate
  /// @param y coordinate
  void lineTo(double x, double y) {
    buf.putNumList(<double>[x, y]);
    buf.putString(" l\n");
  }

  /// This moves the current drawing point.
  ///
  /// @param x coordinate
  /// @param y coordinate
  void moveTo(double x, double y) {
    buf.putNumList(<double>[x, y]);
    buf.putString(" m\n");
  }

  /// Draw a bézier curve
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    buf.putNumList(<double>[x1, y1, x2, y2, x3, y3]);
    buf.putString(" c\n");
  }

  /// https://github.com/deeplook/svglib/blob/master/svglib/svglib.py#L911
  void drawShape(String d, {stroke = true}) {
    final exp = RegExp(r"([MmZzLlHhVvCcSsQqTtAaE])|(-[\.0-9]+)|([\.0-9]+)");
    final matches = exp.allMatches(d + " E");
    String action;
    String lastAction;
    List<double> points;
    PdfPoint lastControl = PdfPoint(0.0, 0.0);
    PdfPoint lastPoint = PdfPoint(0.0, 0.0);
    for (var m in matches) {
      var a = m.group(1);
      var b = m.group(0);

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
            var len = 0;
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
              if ('cCsS'.indexOf(lastAction) >= 0) {
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
            var len = 0;
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
              if ('cCsS'.indexOf(lastAction) >= 0) {
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
          // case 'A': // elliptical arc, absolute
          //   break;
          // case 'a': // elliptical arc, relative
          //   break;
          case 'Z': // close path
          case 'z': // close path
            if (stroke) closePath();
            break;
          default:
            print("Unknown path action: $action");
        }
      }
      lastAction = action;
      action = a;
      points = List<double>();
    }
  }

  /// This is used to add a polygon to the current path.
  /// Used by drawPolygon(), drawPolyline() and fillPolygon() etal
  ///
  /// @param p Array of coordinates
  /// @see #drawPolygon
  /// @see #drawPolyline
  /// @see #fillPolygon
  void _polygon(List<PdfPoint> p) {
    // newPath() not needed here as moveto does it ;-)
    moveTo(p[0].x, p[0].y);

    for (int i = 1; i < p.length; i++) lineTo(p[i].x, p[i].y);
  }

  void setLineCap(PdfLineCap cap) {
    buf.putString("${cap.index} J\n");
  }

  void setLineJoin(PdfLineCap join) {
    buf.putString("${join.index} j\n");
  }

  void setLineWidth(double width) {
    buf.putNum(width);
    buf.putString(" w\n");
  }

  void setMiterLimit(double limit) {
    buf.putNum(limit);
    buf.putString(" M\n");
  }
}
