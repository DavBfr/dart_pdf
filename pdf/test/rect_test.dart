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

import 'package:pdf/src/pdf/point.dart';
import 'package:pdf/src/pdf/rect.dart';
import 'package:test/test.dart';

void main() {
  group('PdfRect', () {
    group('constructors', () {
      test('default constructor', () {
        const rect = PdfRect(10, 20, 30, 40);
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30));
        expect(rect.height, equals(40));
      });

      test('fromLBRT constructor', () {
        final rect = PdfRect.fromLBRT(10, 20, 40, 60);
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30)); // 40 - 10
        expect(rect.height, equals(40)); // 60 - 20
      });

      test('fromPoints constructor', () {
        final offset = PdfPoint(10, 20);
        final size = PdfPoint(30, 40);
        final rect = PdfRect.fromPoints(offset, size);
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30));
        expect(rect.height, equals(40));
      });
    });

    group('constants', () {
      test('zero constant', () {
        expect(PdfRect.zero.left, equals(0));
        expect(PdfRect.zero.bottom, equals(0));
        expect(PdfRect.zero.width, equals(0));
        expect(PdfRect.zero.height, equals(0));
      });
    });

    group('basic properties', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('left property', () {
        expect(rect.left, equals(10));
      });

      test('bottom property', () {
        expect(rect.bottom, equals(20));
      });

      test('width property', () {
        expect(rect.width, equals(30));
      });

      test('height property', () {
        expect(rect.height, equals(40));
      });

      test('right property', () {
        expect(rect.right, equals(40)); // 10 + 30
      });

      test('top property', () {
        expect(rect.top, equals(60)); // 20 + 40
      });
    });

    group('center properties', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('horizontalCenter property', () {
        expect(rect.horizontalCenter, equals(25)); // 10 + 30/2
      });

      test('verticalCenter property', () {
        expect(rect.verticalCenter, equals(40)); // 20 + 40/2
      });
    });

    group('point properties', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('offset property', () {
        final offset = rect.offset;
        expect(offset.x, equals(10));
        expect(offset.y, equals(20));
      });

      test('size property', () {
        final size = rect.size;
        expect(size.x, equals(30));
        expect(size.y, equals(40));
      });

      test('leftBottom property', () {
        final leftBottom = rect.leftBottom;
        expect(leftBottom.x, equals(10));
        expect(leftBottom.y, equals(20));
      });

      test('rightBottom property', () {
        final rightBottom = rect.rightBottom;
        expect(rightBottom.x, equals(40));
        expect(rightBottom.y, equals(20));
      });

      test('leftTop property', () {
        final leftTop = rect.leftTop;
        expect(leftTop.x, equals(10));
        expect(leftTop.y, equals(60));
      });

      test('rightTop property', () {
        final rightTop = rect.rightTop;
        expect(rightTop.x, equals(40));
        expect(rightTop.y, equals(60));
      });
    });

    group('operators', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('multiplication operator', () {
        final scaled = rect * 2;
        expect(scaled.left, equals(20));
        expect(scaled.bottom, equals(40));
        expect(scaled.width, equals(60));
        expect(scaled.height, equals(80));
      });

      test('multiplication by zero', () {
        final scaled = rect * 0;
        expect(scaled.left, equals(0));
        expect(scaled.bottom, equals(0));
        expect(scaled.width, equals(0));
        expect(scaled.height, equals(0));
      });

      test('multiplication by negative factor', () {
        final scaled = rect * -1;
        expect(scaled.left, equals(-10));
        expect(scaled.bottom, equals(-20));
        expect(scaled.width, equals(-30));
        expect(scaled.height, equals(-40));
      });

      test('multiplication by fractional factor', () {
        final scaled = rect * 0.5;
        expect(scaled.left, equals(5));
        expect(scaled.bottom, equals(10));
        expect(scaled.width, equals(15));
        expect(scaled.height, equals(20));
      });
    });

    group('transform methods', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('inflate method', () {
        final inflated = rect.inflate(5);
        expect(inflated.left, equals(5)); // 10 - 5
        expect(inflated.bottom, equals(15)); // 20 - 5
        expect(inflated.right, equals(45)); // 40 + 5
        expect(inflated.top, equals(65)); // 60 + 5
        expect(inflated.width, equals(40)); // original width + 2*5
        expect(inflated.height, equals(50)); // original height + 2*5
      });

      test('inflate with negative value', () {
        final inflated = rect.inflate(-5);
        expect(inflated.left, equals(15)); // 10 - (-5)
        expect(inflated.bottom, equals(25)); // 20 - (-5)
        expect(inflated.right, equals(35)); // 40 + (-5)
        expect(inflated.top, equals(55)); // 60 + (-5)
        expect(inflated.width, equals(20)); // original width + 2*(-5)
        expect(inflated.height, equals(30)); // original height + 2*(-5)
      });

      test('deflate method', () {
        final deflated = rect.deflate(5);
        expect(deflated.left, equals(15)); // 10 + 5
        expect(deflated.bottom, equals(25)); // 20 + 5
        expect(deflated.right, equals(35)); // 40 - 5
        expect(deflated.top, equals(55)); // 60 - 5
        expect(deflated.width, equals(20)); // original width - 2*5
        expect(deflated.height, equals(30)); // original height - 2*5
      });

      test('deflate with negative value', () {
        final deflated = rect.deflate(-5);
        expect(deflated.left, equals(5)); // 10 + (-5)
        expect(deflated.bottom, equals(15)); // 20 + (-5)
        expect(deflated.right, equals(45)); // 40 - (-5)
        expect(deflated.top, equals(65)); // 60 - (-5)
        expect(deflated.width, equals(40)); // original width - 2*(-5)
        expect(deflated.height, equals(50)); // original height - 2*(-5)
      });

      test('inflate then deflate returns to original', () {
        final inflated = rect.inflate(10);
        final back = inflated.deflate(10);
        expect(back.left, equals(rect.left));
        expect(back.bottom, equals(rect.bottom));
        expect(back.width, equals(rect.width));
        expect(back.height, equals(rect.height));
      });
    });

    group('copyWith method', () {
      const rect = PdfRect(10, 20, 30, 40);

      test('copyWith no parameters returns same values', () {
        final copy = rect.copyWith();
        expect(copy.left, equals(rect.left));
        expect(copy.bottom, equals(rect.bottom));
        expect(copy.width, equals(rect.width));
        expect(copy.height, equals(rect.height));
      });

      test('copyWith left parameter', () {
        final copy = rect.copyWith(left: 15);
        expect(copy.left, equals(15));
        expect(copy.bottom, equals(rect.bottom));
        expect(copy.width, equals(rect.width));
        expect(copy.height, equals(rect.height));
      });

      test('copyWith bottom parameter', () {
        final copy = rect.copyWith(bottom: 25);
        expect(copy.left, equals(rect.left));
        expect(copy.bottom, equals(25));
        expect(copy.width, equals(rect.width));
        expect(copy.height, equals(rect.height));
      });

      test('copyWith width parameter', () {
        final copy = rect.copyWith(width: 35);
        expect(copy.left, equals(rect.left));
        expect(copy.bottom, equals(rect.bottom));
        expect(copy.width, equals(35));
        expect(copy.height, equals(rect.height));
      });

      test('copyWith height parameter', () {
        final copy = rect.copyWith(height: 45);
        expect(copy.left, equals(rect.left));
        expect(copy.bottom, equals(rect.bottom));
        expect(copy.width, equals(rect.width));
        expect(copy.height, equals(45));
      });

      test('copyWith all parameters', () {
        final copy = rect.copyWith(left: 5, bottom: 15, width: 25, height: 35);
        expect(copy.left, equals(5));
        expect(copy.bottom, equals(15));
        expect(copy.width, equals(25));
        expect(copy.height, equals(35));
      });
    });

    group('toString method', () {
      test('toString returns correct format', () {
        const rect = PdfRect(10, 20, 30, 40);
        expect(rect.toString(), equals('PdfRect(10.0, 20.0, 30.0, 40.0)'));
      });

      test('toString with zero values', () {
        expect(PdfRect.zero.toString(), equals('PdfRect(0.0, 0.0, 0.0, 0.0)'));
      });

      test('toString with negative values', () {
        const rect = PdfRect(-10, -20, 30, 40);
        expect(rect.toString(), equals('PdfRect(-10.0, -20.0, 30.0, 40.0)'));
      });

      test('toString with fractional values', () {
        const rect = PdfRect(10.5, 20.25, 30.75, 40.125);
        expect(rect.toString(), equals('PdfRect(10.5, 20.25, 30.75, 40.125)'));
      });
    });

    group('edge cases', () {
      test('zero width rectangle', () {
        const rect = PdfRect(10, 20, 0, 40);
        expect(rect.left, equals(rect.right));
        expect(rect.horizontalCenter, equals(10));
      });

      test('zero height rectangle', () {
        const rect = PdfRect(10, 20, 30, 0);
        expect(rect.bottom, equals(rect.top));
        expect(rect.verticalCenter, equals(20));
      });

      test('negative width rectangle', () {
        const rect = PdfRect(10, 20, -30, 40);
        expect(rect.width, equals(-30));
        expect(rect.right, equals(-20)); // 10 + (-30)
        expect(rect.horizontalCenter, equals(-5)); // 10 + (-30)/2
      });

      test('negative height rectangle', () {
        const rect = PdfRect(10, 20, 30, -40);
        expect(rect.height, equals(-40));
        expect(rect.top, equals(-20)); // 20 + (-40)
        expect(rect.verticalCenter, equals(0)); // 20 + (-40)/2
      });

      test('very large values', () {
        const rect = PdfRect(1e6, 1e6, 1e6, 1e6);
        expect(rect.left, equals(1e6));
        expect(rect.bottom, equals(1e6));
        expect(rect.width, equals(1e6));
        expect(rect.height, equals(1e6));
        expect(rect.right, equals(2e6));
        expect(rect.top, equals(2e6));
      });

      test('very small fractional values', () {
        const rect = PdfRect(1e-10, 1e-10, 1e-10, 1e-10);
        expect(rect.left, equals(1e-10));
        expect(rect.bottom, equals(1e-10));
        expect(rect.width, equals(1e-10));
        expect(rect.height, equals(1e-10));
      });
    });

    group('immutability', () {
      test('PdfRect is immutable', () {
        const rect = PdfRect(10, 20, 30, 40);
        final scaled = rect * 2;

        // Original rect should remain unchanged
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30));
        expect(rect.height, equals(40));

        // Scaled rect should be different
        expect(scaled.left, equals(20));
        expect(scaled.bottom, equals(40));
        expect(scaled.width, equals(60));
        expect(scaled.height, equals(80));
      });

      test('inflate does not modify original', () {
        const rect = PdfRect(10, 20, 30, 40);
        final inflated = rect.inflate(5);

        // Original rect should remain unchanged
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30));
        expect(rect.height, equals(40));

        // Inflated rect should be different
        expect(inflated.left, equals(5));
        expect(inflated.bottom, equals(15));
        expect(inflated.width, equals(40));
        expect(inflated.height, equals(50));
      });

      test('copyWith does not modify original', () {
        const rect = PdfRect(10, 20, 30, 40);
        final copy = rect.copyWith(left: 15);

        // Original rect should remain unchanged
        expect(rect.left, equals(10));
        expect(rect.bottom, equals(20));
        expect(rect.width, equals(30));
        expect(rect.height, equals(40));

        // Copy should be different
        expect(copy.left, equals(15));
        expect(copy.bottom, equals(20));
        expect(copy.width, equals(30));
        expect(copy.height, equals(40));
      });
    });
  });
}
