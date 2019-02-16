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

class Ascii85Encoder extends Converter<List<int>, List<int>> {
  @override
  List<int> convert(List<int> input) {
    final Uint8List buffer = Uint8List(_maxEncodedLen(input.length) + 2);

    int b = 0;
    int s = 0;

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
      int m = 5;
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
