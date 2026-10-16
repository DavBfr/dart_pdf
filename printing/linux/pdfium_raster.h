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

#ifndef PACKAGES_PRINTING_PDFIUM_RASTER_H_
#define PACKAGES_PRINTING_PDFIUM_RASTER_H_

// Size arithmetic and pixel conversion for the pdfium raster path.
//
// No pdfium and no platform dependency, so it can be compiled and exercised on
// any host. This file exists verbatim in printing/windows and printing/linux,
// which are separate build trees; keep the two copies identical.

#include <cmath>
#include <cstddef>
#include <cstdint>

namespace nfet {

/// The largest raster this will attempt, in bytes.
///
/// pdfium returns a null bitmap once pitch * height reaches 4 GiB, and the
/// buffer has to be copied over the method channel afterwards. 1 GiB is well
/// clear of both, and an A0 page at 600 dpi - the reported crash - is above it.
constexpr size_t kMaxRasterBytes = 1024u * 1024u * 1024u;

/// The pixel size of one rastered page.
struct RasterSize {
  int width = 0;
  int height = 0;
  size_t stride = 0;
  size_t bytes = 0;

  /// Whether this page can be rastered at all.
  ///
  /// False for a non-positive size, which makes FPDFBitmap_Create return null,
  /// and for a buffer this refuses to allocate. The caller used to pass either
  /// straight to pdfium and then write through the null buffer the failed
  /// create gave back, taking the whole process down with an access violation
  /// or a SIGSEGV and no Dart error at all.
  bool valid = false;
};

/// Work out how big a page rasters at `scale`.
///
/// Every value is computed in double and then in size_t. The old code held the
/// buffer length as `bHeight * stride` and each row offset as `y * stride`,
/// both int, which overflows above 2 GiB.
inline RasterSize rasterSizeFor(double pageWidth,
                                double pageHeight,
                                double scale,
                                size_t limitBytes = kMaxRasterBytes) {
  RasterSize size;

  if (!std::isfinite(pageWidth) || !std::isfinite(pageHeight) ||
      !std::isfinite(scale) || scale <= 0) {
    return size;
  }

  const double width = pageWidth * scale;
  const double height = pageHeight * scale;

  // Below one pixel, or past what an int can hold: pdfium takes ints.
  if (width < 1 || height < 1 || width > 2147483647.0 ||
      height > 2147483647.0) {
    return size;
  }

  const size_t stride = static_cast<size_t>(width) * 4;
  const size_t bytes = stride * static_cast<size_t>(height);

  // Division rather than multiplication, so the check itself cannot overflow.
  if (stride == 0 || bytes / stride != static_cast<size_t>(height) ||
      bytes > limitBytes) {
    return size;
  }

  size.width = static_cast<int>(width);
  size.height = static_cast<int>(height);
  size.stride = stride;
  size.bytes = bytes;
  size.valid = true;
  return size;
}

/// Convert pdfium's output in place, from BGRA with straight alpha to RGBA with
/// premultiplied alpha.
///
/// `ui.decodeImageFromPixels` reads rgba8888 as premultiplied. The loop this
/// replaces only swapped the channels, which was invisible while every pixel
/// was fully transparent and is invisible for an opaque page, but left a
/// partially transparent page too bright.
inline void bgraToPremultipliedRgba(uint8_t* pixels,
                                    int width,
                                    int height,
                                    size_t stride) {
  if (pixels == nullptr || width <= 0 || height <= 0) {
    return;
  }

  for (int y = 0; y < height; y++) {
    size_t offset = static_cast<size_t>(y) * stride;
    for (int x = 0; x < width; x++) {
      const uint8_t b = pixels[offset];
      const uint8_t g = pixels[offset + 1];
      const uint8_t r = pixels[offset + 2];
      const uint8_t a = pixels[offset + 3];

      if (a == 255) {
        pixels[offset] = r;
        pixels[offset + 2] = b;
      } else {
        pixels[offset] = static_cast<uint8_t>((r * a + 127) / 255);
        pixels[offset + 1] = static_cast<uint8_t>((g * a + 127) / 255);
        pixels[offset + 2] = static_cast<uint8_t>((b * a + 127) / 255);
      }

      offset += 4;
    }
  }
}

}  // namespace nfet

#endif  // PACKAGES_PRINTING_PDFIUM_RASTER_H_
