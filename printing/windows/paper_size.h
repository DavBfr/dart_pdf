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

#ifndef PACKAGES_PRINTING_WINDOWS_PAPER_SIZE_H_
#define PACKAGES_PRINTING_WINDOWS_PAPER_SIZE_H_

#include <cmath>

// Only the DMPAPER_* form numbers are needed from the Win32 headers, so this
// header stays testable on any host.
#ifndef DMPAPER_LETTER
#define DMPAPER_LETTER 1
#define DMPAPER_LEGAL 5
#define DMPAPER_A3 8
#define DMPAPER_A4 9
#define DMPAPER_A5 11
#define DMPAPER_A6 70
#define DMPAPER_USER 256
#endif

namespace nfet {

/// A sheet to ask the driver for.
///
/// `paperSize` is a DMPAPER_* form number, and is DMPAPER_USER when the size
/// matches no standard form. `widthTenthsMm` and `lengthTenthsMm` describe the
/// portrait sheet, and are 0 when the size cannot be expressed (an infinite
/// roll format, or one that does not fit a 16-bit field).
struct PaperSelection {
  short paperSize;
  short widthTenthsMm;
  short lengthTenthsMm;

  /// Whether the driver should be given explicit dimensions.
  bool hasDimensions() const { return widthTenthsMm > 0 && lengthTenthsMm > 0; }

  /// Whether a standard form was recognised.
  bool isStandardForm() const { return paperSize != DMPAPER_USER; }
};

/// Convert PDF points to tenths of a millimetre, the unit DEVMODE uses.
///
/// Returns 0 for a value that is not finite - roll formats carry infinity -
/// or that does not fit the 16-bit field, so the caller can leave the
/// dimension out instead of casting undefined behaviour into a short.
inline short pointsToTenthsMm(double points) {
  if (!std::isfinite(points) || points <= 0) {
    return 0;
  }
  const double tenths = std::round(points * 254 / 72);
  if (tenths < 1 || tenths > 32767) {
    return 0;
  }
  return static_cast<short>(tenths);
}

/// Pick the DMPAPER_* form for a portrait sheet, or DMPAPER_USER.
///
/// A dmPaperSize of 0 is not a valid form number: drivers that see it fall
/// back to their own default paper, which is why a requested page format used
/// to be ignored.
inline PaperSelection selectPaper(double portraitWidthPt,
                                  double portraitHeightPt) {
  const short width = pointsToTenthsMm(portraitWidthPt);
  const short length = pointsToTenthsMm(portraitHeightPt);

  struct Form {
    short paperSize;
    short width;
    short length;
  };

  // The formats of pdf/lib/src/pdf/page_format.dart, in tenths of a mm.
  static const Form forms[] = {
      {DMPAPER_A3, 2970, 4200},     {DMPAPER_A4, 2100, 2970},
      {DMPAPER_A5, 1480, 2100},     {DMPAPER_A6, 1050, 1480},
      {DMPAPER_LETTER, 2159, 2794}, {DMPAPER_LEGAL, 2159, 3556},
  };

  if (width > 0 && length > 0) {
    // Tolerance covers the rounding plus the 0.01pt slop in the point values.
    const short tolerance = 2;
    for (const auto& form : forms) {
      if (std::abs(width - form.width) <= tolerance &&
          std::abs(length - form.length) <= tolerance) {
        return PaperSelection{form.paperSize, width, length};
      }
    }
  }

  return PaperSelection{DMPAPER_USER, width, length};
}

}  // namespace nfet

#endif  // PACKAGES_PRINTING_WINDOWS_PAPER_SIZE_H_
