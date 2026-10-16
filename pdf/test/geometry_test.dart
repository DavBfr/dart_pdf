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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// Every directional constant, with the physical one it means in an ltr
/// document and the one it means in an rtl document.
const resolutions = <String, List<AlignmentGeometry>>{
  'topStart': <AlignmentGeometry>[
    AlignmentDirectional.topStart,
    Alignment.topLeft,
    Alignment.topRight,
  ],
  'topCenter': <AlignmentGeometry>[
    AlignmentDirectional.topCenter,
    Alignment.topCenter,
    Alignment.topCenter,
  ],
  'topEnd': <AlignmentGeometry>[
    AlignmentDirectional.topEnd,
    Alignment.topRight,
    Alignment.topLeft,
  ],
  'centerStart': <AlignmentGeometry>[
    AlignmentDirectional.centerStart,
    Alignment.centerLeft,
    Alignment.centerRight,
  ],
  'center': <AlignmentGeometry>[
    AlignmentDirectional.center,
    Alignment.center,
    Alignment.center,
  ],
  'centerEnd': <AlignmentGeometry>[
    AlignmentDirectional.centerEnd,
    Alignment.centerRight,
    Alignment.centerLeft,
  ],
  'bottomStart': <AlignmentGeometry>[
    AlignmentDirectional.bottomStart,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ],
  'bottomCenter': <AlignmentGeometry>[
    AlignmentDirectional.bottomCenter,
    Alignment.bottomCenter,
    Alignment.bottomCenter,
  ],
  'bottomEnd': <AlignmentGeometry>[
    AlignmentDirectional.bottomEnd,
    Alignment.bottomRight,
    Alignment.bottomLeft,
  ],
};

/// [PdfRect] has no value equality, so compare the four numbers.
Matcher isRect(double x, double y, double w, double h) => predicate<PdfRect>(
  (PdfRect r) => r.x == x && r.y == y && r.width == w && r.height == h,
  'PdfRect($x, $y, $w, $h)',
);

void main() {
  group('an Alignment', () {
    test('runs y up, so topLeft inscribes at the top', () {
      // The convention this whole family hangs on, and the one the directional
      // constants were copied from Flutter without.
      expect(Alignment.topLeft.y, 1.0);
      expect(Alignment.bottomLeft.y, -1.0);

      expect(
        Alignment.topLeft.inscribe(
          const PdfPoint(10, 10),
          const PdfRect(0, 0, 100, 100),
        ),
        isRect(0, 90, 10, 10),
      );
      expect(
        Alignment.bottomRight.inscribe(
          const PdfPoint(10, 10),
          const PdfRect(0, 0, 100, 100),
        ),
        isRect(90, 0, 10, 10),
      );
    });

    test('names itself after the corner it is', () {
      // The label table was the y-down one, so every constant printed the name
      // of its vertical opposite: Alignment.topLeft said 'Alignment.bottomLeft'.
      expect(Alignment.topLeft.toString(), 'Alignment.topLeft');
      expect(Alignment.topCenter.toString(), 'Alignment.topCenter');
      expect(Alignment.topRight.toString(), 'Alignment.topRight');
      expect(Alignment.centerLeft.toString(), 'Alignment.centerLeft');
      expect(Alignment.center.toString(), 'Alignment.center');
      expect(Alignment.centerRight.toString(), 'Alignment.centerRight');
      expect(Alignment.bottomLeft.toString(), 'Alignment.bottomLeft');
      expect(Alignment.bottomCenter.toString(), 'Alignment.bottomCenter');
      expect(Alignment.bottomRight.toString(), 'Alignment.bottomRight');
      expect(const Alignment(0.5, -0.75).toString(), 'Alignment(0.5, -0.8)');
    });
  });

  group('an AlignmentDirectional', () {
    test('resolves to the physical constant of the same name', () {
      // The six vertical constants were Flutter's y-down ones, and resolve()
      // mirrors x only - so topStart put its child at the bottom of the box and
      // a topCenter-to-bottomCenter gradient ran backwards.
      resolutions.forEach((String name, List<AlignmentGeometry> v) {
        final directional = v[0] as AlignmentDirectional;
        final ltr = directional.resolve(TextDirection.ltr);
        final rtl = directional.resolve(TextDirection.rtl);

        expect(ltr.x, (v[1] as Alignment).x, reason: '$name ltr x');
        expect(ltr.y, (v[1] as Alignment).y, reason: '$name ltr y');
        expect(rtl.x, (v[2] as Alignment).x, reason: '$name rtl x');
        expect(rtl.y, (v[2] as Alignment).y, reason: '$name rtl y');
      });
    });

    test('inscribes where the physical one does', () {
      expect(
        AlignmentDirectional.topStart
            .resolve(TextDirection.ltr)
            .inscribe(const PdfPoint(10, 10), const PdfRect(0, 0, 100, 100)),
        isRect(0, 90, 10, 10),
      );
      expect(
        AlignmentDirectional.topStart
            .resolve(TextDirection.rtl)
            .inscribe(const PdfPoint(10, 10), const PdfRect(0, 0, 100, 100)),
        isRect(90, 90, 10, 10),
      );
    });

    test('leaves the y == 0 constants where they were', () {
      for (final name in <String>['centerStart', 'center', 'centerEnd']) {
        final directional = resolutions[name]!.first as AlignmentDirectional;
        expect(directional.y, 0.0, reason: name);
      }
    });

    test('names itself after the corner it is', () {
      expect(
        AlignmentDirectional.topStart.toString(),
        'AlignmentDirectional.topStart',
      );
      expect(
        AlignmentDirectional.topCenter.toString(),
        'AlignmentDirectional.topCenter',
      );
      expect(
        AlignmentDirectional.topEnd.toString(),
        'AlignmentDirectional.topEnd',
      );
      expect(
        AlignmentDirectional.centerStart.toString(),
        'AlignmentDirectional.centerStart',
      );
      expect(
        AlignmentDirectional.center.toString(),
        'AlignmentDirectional.center',
      );
      expect(
        AlignmentDirectional.centerEnd.toString(),
        'AlignmentDirectional.centerEnd',
      );
      expect(
        AlignmentDirectional.bottomStart.toString(),
        'AlignmentDirectional.bottomStart',
      );
      expect(
        AlignmentDirectional.bottomCenter.toString(),
        'AlignmentDirectional.bottomCenter',
      );
      expect(
        AlignmentDirectional.bottomEnd.toString(),
        'AlignmentDirectional.bottomEnd',
      );
    });
  });

  test('a FractionalOffset keeps the same y-up convention', () {
    // dy = 0 is the top, as for Alignment.
    expect(const FractionalOffset(0, 0).y, 1.0);
    expect(const FractionalOffset(0, 1).y, -1.0);
    expect(const FractionalOffset(0, 0).x, Alignment.topLeft.x);
  });
}
