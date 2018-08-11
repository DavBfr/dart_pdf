/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class Ascii85Encoder extends Converter<Uint8List, Uint8List> {
  Uint8List convert(Uint8List input) {
    Uint8List buffer = new Uint8List(_maxEncodedLen(input.length) + 2);

    var b = 0;
    var s = 0;

    while (s < input.length) {
      buffer[b + 0] = 0;
      buffer[b + 1] = 0;
      buffer[b + 2] = 0;
      buffer[b + 3] = 0;
      buffer[b + 4] = 0;

      // Unpack 4 bytes into int to repack into base 85 5-byte.
      int v = 0;

      switch (input.length - s) {
        case 3:
          v |= input[s + 0] << 24;
          v |= input[s + 1] << 16;
          v |= input[s + 2] << 8;
          break;
        case 2:
          v |= input[s + 0] << 24;
          v |= input[s + 1] << 16;
          break;
        case 1:
          v |= input[s + 0] << 24;
          break;
        default:
          v |= input[s + 0] << 24;
          v |= input[s + 1] << 16;
          v |= input[s + 2] << 8;
          v |= input[s + 3];
      }

      // Special case: zero (!!!!!) shortens to z.
      if (v == 0 && input.length - s >= 4) {
        buffer[b] = 122;
        b++;
        s += 4;
        continue;
      }

      // Otherwise, 5 base 85 digits starting at !.
      for (int i = 4; i >= 0; i--) {
        buffer[b + i] = 33 + v % 85;
        v ~/= 85;
      }

      // If input was short, discard the low destination bytes.
      var m = 5;
      if (input.length - s < 4) {
        m -= 4 - (input.length - s);
        break;
      } else {
        s += 4;
      }

      b += m;
    }

    buffer[b] = 0x7e;
    buffer[b + 1] = 0x3e;

    return buffer.sublist(0, b + 2);
  }

  int _maxEncodedLen(int n) => (n + 3) ~/ 4 * 5;
}
