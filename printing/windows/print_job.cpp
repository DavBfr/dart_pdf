/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "print_job.h"

#include "paper_size.h"
#include "printing.h"

#include <fpdfview.h>
#include <objbase.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <tchar.h>
#include <codecvt>
#include <fstream>
#include <iterator>
#include <numeric>

namespace nfet {

const auto pdfDpi = 72;

std::string toUtf8(std::wstring wstr) {
  int cbMultiByte = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr,
                                        0, nullptr, nullptr);
  LPSTR lpMultiByteStr = (LPSTR)malloc(cbMultiByte);
  cbMultiByte =
      WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, lpMultiByteStr,
                          cbMultiByte, nullptr, nullptr);
  std::string ret = lpMultiByteStr;
  free(lpMultiByteStr);
  return ret;
}

std::string toUtf8(TCHAR* tstr) {
#ifndef UNICODE
#error "Non unicode build not supported"
#endif

  if (!tstr) {
    return std::string{};
  }

  return toUtf8(std::wstring{tstr});
}

std::wstring fromUtf8(std::string str) {
  auto len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                                 static_cast<int>(str.length()), nullptr, 0);
  if (len <= 0) {
    return L"";
  }

  auto wstr = std::wstring{};
  wstr.resize(len);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.length()),
                      &wstr[0], len);

  return wstr;
}

/// Describe the last Win32 error, prefixed with what was being attempted.
///
/// Returns an empty string for a cancellation, so the Dart side completes with
/// false instead of throwing: the user cancelling a Save-As dialog is not an
/// error.
std::string lastErrorMessage(const std::string& what) {
  const auto code = GetLastError();

  if (code == ERROR_CANCELLED || code == ERROR_PRINT_CANCELLED) {
    return std::string{};
  }

  LPWSTR text = nullptr;
  const auto length = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&text), 0, nullptr);

  auto message = what;
  if (length > 0 && text != nullptr) {
    auto detail = std::wstring{text, length};
    while (!detail.empty() &&
           (detail.back() == L'\r' || detail.back() == L'\n')) {
      detail.pop_back();
    }
    message += ": " + toUtf8(detail);
  } else {
    message += " (error " + std::to_string(code) + ")";
  }

  if (text != nullptr) {
    LocalFree(text);
  }

  return message;
}

PrintJob::PrintJob(Printing* printing, int index)
    : printing{printing}, index{index} {}

bool PrintJob::printPdf(const std::string& name,
                        std::string printer,
                        double width,
                        double height,
                        bool usePrinterSettings,
                        bool windowsModernDialog) {
  documentName = name;

  // Only allocate when the DEVMODE will be used: the usePrinterSettings path
  // used to allocate one and then drop the pointer, leaking it on every job.
  DEVMODE* dm = nullptr;

  if (!usePrinterSettings) {
    const std::size_t dmSize = sizeof(DEVMODE);
    std::size_t dmExtra = 0;

    if (!printer.empty()) {
      // DeviceCapabilities answers -1 for an unknown or unavailable printer;
      // assigning that to an unsigned type wrapped it to SIZE_MAX, so the
      // allocation failed and dmDriverExtra claimed 65535 bytes of a struct
      // that was never allocated.
      const int extra = DeviceCapabilities(fromUtf8(printer).c_str(), nullptr,
                                           DC_EXTRA, nullptr, nullptr);
      if (extra < 0) {
        cancelJob("Unknown or unavailable printer: " + printer);
        return false;
      }
      dmExtra = static_cast<std::size_t>(extra);
    }

    dm = static_cast<DEVMODE*>(GlobalAlloc(GMEM_FIXED, dmSize + dmExtra));
    if (!dm) {
      cancelJob("Out of memory allocating the printer settings");
      return false;
    }

    ZeroMemory(dm, dmSize + dmExtra);
    dm->dmSize = (WORD)dmSize;
    dm->dmDriverExtra = (WORD)dmExtra;

    // dmPaperSize, dmPaperWidth and dmPaperLength always describe the portrait
    // sheet; dmOrientation rotates it. A zero axis means 'unspecified' in the
    // channel protocol, and selectPaper() drops it, so the driver keeps its
    // own paper for that axis instead of being handed a wrapped short.
    const auto portraitWidth = width > height ? height : width;
    const auto portraitHeight = width > height ? width : height;
    const auto paper = selectPaper(portraitWidth, portraitHeight);

    dm->dmOrientation = width > height ? DMORIENT_LANDSCAPE : DMORIENT_PORTRAIT;
    dm->dmFields = DM_ORIENTATION;

    if (paper.isStandardForm()) {
      // A dmPaperSize of 0, as this used to send, is not a valid form number,
      // so drivers fell back to their own default paper. Do not also send the
      // dimensions: they would override the form.
      dm->dmFields |= DM_PAPERSIZE;
      dm->dmPaperSize = paper.paperSize;
    } else if (paper.hasDimensions()) {
      dm->dmFields |= DM_PAPERSIZE | DM_PAPERLENGTH | DM_PAPERWIDTH;
      dm->dmPaperSize = DMPAPER_USER;
      dm->dmPaperWidth = paper.widthTenthsMm;
      dm->dmPaperLength = paper.lengthTenthsMm;
    }
    // Otherwise the size cannot be expressed - a roll format carries infinity
    // - so ask only for the orientation and let the driver choose the media.
  }

  // nullptr when the engine has no view; both dialogs then keep the owner
  // they had before.
  auto owner = printing->getWindow();

  if (printer.empty()) {
    if (windowsModernDialog) {
      // --- MODERN OPTION (PrintDlgEx) ---
      PRINTDLGEX pdx = {0};
      pdx.lStructSize = sizeof(PRINTDLGEX);
      pdx.hwndOwner = owner ? owner : GetActiveWindow();
      pdx.hDevMode = dm;
      dm = nullptr;  // dialog takes ownership; may replace with new alloc
      pdx.hDevNames = nullptr;
      pdx.hDC = nullptr;

      // Flags: Use PD_RETURNDC to get the context we need for PDFium
      pdx.Flags = PD_RETURNDC | PD_USEDEVMODECOPIESANDCOLLATE | PD_NOPAGENUMS |
                  PD_NOSELECTION;

      pdx.nStartPage = START_PAGE_GENERAL;
      pdx.nMaxPageRanges = 1;
      PRINTPAGERANGE ranges[1] = {{1, 1}};  // Required structure for PDX
      pdx.lpPageRanges = ranges;

      HRESULT hr = PrintDlgEx(&pdx);

      // Check if the user actually clicked "Print"
      if (hr == S_OK && pdx.dwResultAction == PD_RESULT_PRINT) {
        this->hDC = pdx.hDC;
        this->hDevMode = pdx.hDevMode;
        this->hDevNames = pdx.hDevNames;
        // success = true;
      } else {
        // User cancelled or error occurred — notify Dart so its future
        // completes.
        if (pdx.hDC)
          DeleteDC(pdx.hDC);
        if (pdx.hDevMode)
          GlobalFree(pdx.hDevMode);
        if (pdx.hDevNames)
          GlobalFree(pdx.hDevNames);
        printing->onCompleted(this, false, "");
        return false;
      }
    } else {
      // --- CLASSIC DEFAULT  ---
      PRINTDLG pd;
      ZeroMemory(&pd, sizeof(pd));
      pd.lStructSize = sizeof(pd);
      pd.hwndOwner = owner;
      pd.hDevMode = dm;
      dm = nullptr;  // dialog takes ownership; may replace with new alloc
      pd.hDevNames = nullptr;
      pd.hDC = nullptr;
      pd.Flags = PD_USEDEVMODECOPIES | PD_RETURNDC | PD_PRINTSETUP |
                 PD_NOSELECTION | PD_NOPAGENUMS;
      pd.nCopies = 1;
      pd.nFromPage = 0xFFFF;
      pd.nToPage = 0xFFFF;
      pd.nMinPage = 1;
      pd.nMaxPage = 0xFFFF;

      auto r = PrintDlg(&pd);

      if (r != 1) {
        // User cancelled or error occurred - release what the dialog handed
        // back, notify Dart so its future completes, then return false so the
        // caller reclaims this job. Returning true leaked one job per cancel,
        // because nothing was ever handed a pointer to it.
        if (pd.hDC)
          DeleteDC(pd.hDC);
        if (pd.hDevNames)
          GlobalFree(pd.hDevNames);
        if (pd.hDevMode)
          GlobalFree(pd.hDevMode);
        printing->onCompleted(this, false, "");
        return false;
      }

      hDC = pd.hDC;
      hDevMode = pd.hDevMode;
      hDevNames = pd.hDevNames;
    }
  } else {
    // Take ownership before the call can fail, so cancelJob() below releases
    // the DEVMODE instead of leaking it.
    hDevMode = dm;
    hDevNames = nullptr;
    hDC = CreateDC(TEXT("WINSPOOL"), fromUtf8(printer).c_str(), nullptr, dm);
    if (!hDC) {
      // The caller deletes this job, so nothing could report the failure
      // later: the Dart future would wait for ever.
      cancelJob("Cannot open the printer '" + printer + "'");
      return false;
    }
  }

  auto dpiX = static_cast<double>(GetDeviceCaps(hDC, LOGPIXELSX)) / pdfDpi;
  auto dpiY = static_cast<double>(GetDeviceCaps(hDC, LOGPIXELSY)) / pdfDpi;
  auto pageWidth =
      static_cast<double>(GetDeviceCaps(hDC, PHYSICALWIDTH)) / dpiX;
  auto pageHeight =
      static_cast<double>(GetDeviceCaps(hDC, PHYSICALHEIGHT)) / dpiY;
  auto printableWidth = static_cast<double>(GetDeviceCaps(hDC, HORZRES)) / dpiX;
  auto printableHeight =
      static_cast<double>(GetDeviceCaps(hDC, VERTRES)) / dpiY;
  auto marginLeft =
      static_cast<double>(GetDeviceCaps(hDC, PHYSICALOFFSETX)) / dpiX;
  auto marginTop =
      static_cast<double>(GetDeviceCaps(hDC, PHYSICALOFFSETY)) / dpiY;
  auto marginRight = pageWidth - printableWidth - marginLeft;
  auto marginBottom = pageHeight - printableHeight - marginTop;

  printing->onLayout(this, pageWidth, pageHeight, marginLeft, marginTop,
                     marginRight, marginBottom);
  return true;
}

std::vector<Printer> PrintJob::listPrinters(std::string* error) {
  // Both buffers are vectors, so no exit path can leak them - the malloc'd
  // default-printer name used to leak on every early return - and neither
  // allocation needs a null check.
  DWORD size = 0;
  GetDefaultPrinter(nullptr, &size);

  auto defaultPrinter = std::vector<TCHAR>(size > 0 ? size : 1);
  if (size == 0 || !GetDefaultPrinter(defaultPrinter.data(), &size)) {
    size = 0;
  }

  auto printers = std::vector<Printer>{};
  const auto flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;

  DWORD needed = 0;
  DWORD returned = 0;
  auto buffer = std::vector<BYTE>{};

  // Probe then fill is a race: a printer added in between makes the fill fail
  // with ERROR_INSUFFICIENT_BUFFER, which used to be reported as a machine
  // with no printers at all.
  for (auto attempt = 0; attempt < 3; attempt++) {
    needed = 0;
    returned = 0;
    EnumPrinters(flags, nullptr, 2, nullptr, 0, &needed, &returned);

    if (needed == 0) {
      // No printers, which is not a failure.
      return printers;
    }

    buffer.assign(needed, 0);
    if (EnumPrinters(flags, nullptr, 2, buffer.data(), needed, &needed,
                     &returned) != 0) {
      const auto info = reinterpret_cast<PRINTER_INFO_2*>(buffer.data());

      for (DWORD i = 0; i < returned; i++) {
        printers.push_back(
            Printer{toUtf8(info[i].pPrinterName), toUtf8(info[i].pPrinterName),
                    toUtf8(info[i].pDriverName), toUtf8(info[i].pLocation),
                    toUtf8(info[i].pComment),
                    size > 0 && _tcsncmp(info[i].pPrinterName,
                                         defaultPrinter.data(), size) == 0,
                    (info[i].Status &
                     (PRINTER_STATUS_NOT_AVAILABLE | PRINTER_STATUS_ERROR |
                      PRINTER_STATUS_OFFLINE | PRINTER_STATUS_PAUSED)) == 0});
      }

      return printers;
    }

    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      break;
    }
  }

  if (error != nullptr) {
    *error = lastErrorMessage("Unable to list the printers");
  }
  return printers;
}

void PrintJob::writeJob(std::vector<uint8_t> data) {
  auto dpiX = static_cast<double>(GetDeviceCaps(hDC, LOGPIXELSX)) / pdfDpi;
  auto dpiY = static_cast<double>(GetDeviceCaps(hDC, LOGPIXELSY)) / pdfDpi;

  DOCINFO docInfo;

  ZeroMemory(&docInfo, sizeof(docInfo));
  docInfo.cbSize = sizeof(docInfo);

  auto docName = fromUtf8(documentName);
  docInfo.lpszDocName = docName.c_str();

  // StartDoc's result used to be overwritten and never read, so a job that was
  // never spooled - Save-As cancelled, out of paper, access denied, spooler
  // stopped - still reported success.
  if (StartDoc(hDC, &docInfo) <= 0) {
    // A cancellation gives an empty message, which Dart completes as false
    // rather than throwing.
    failJob(lastErrorMessage("Unable to start the print job"));
    return;
  }
  documentOpen = true;

  auto doc = FPDF_LoadMemDocument64(data.data(), data.size(), nullptr);
  if (!doc) {
    // Returning here without calling onCompleted() leaves the Dart-side Future
    // pending forever.
    failJob("Cannot print a malformed PDF file");
    return;
  }

  auto pages = FPDF_GetPageCount(doc);
  auto marginLeft = GetDeviceCaps(hDC, PHYSICALOFFSETX);
  auto marginTop = GetDeviceCaps(hDC, PHYSICALOFFSETY);

  for (auto pageNum = 0; pageNum < pages; pageNum++) {
    if (StartPage(hDC) <= 0) {
      const auto message = lastErrorMessage("Unable to start a printed page");
      FPDF_CloseDocument(doc);
      failJob(message);
      return;
    }

    auto page = FPDF_LoadPage(doc, pageNum);
    if (!page) {
      // A page pdfium cannot load is left blank rather than failing the whole
      // document, but the page itself still has to close cleanly.
      if (EndPage(hDC) <= 0) {
        const auto message =
            lastErrorMessage("Unable to finish a printed page");
        FPDF_CloseDocument(doc);
        failJob(message);
        return;
      }
      continue;
    }

    auto pdfWidth = FPDF_GetPageWidth(page);
    auto pdfHeight = FPDF_GetPageHeight(page);

    int bWidth = static_cast<int>(pdfWidth * dpiX);
    int bHeight = static_cast<int>(pdfHeight * dpiY);

    FPDF_RenderPage(hDC, page, -marginLeft, -marginTop, bWidth, bHeight, 0,
                    FPDF_ANNOT | FPDF_PRINTING);
    FPDF_ClosePage(page);

    if (EndPage(hDC) <= 0) {
      const auto message = lastErrorMessage("Unable to finish a printed page");
      FPDF_CloseDocument(doc);
      failJob(message);
      return;
    }
  }

  // EndDoc before closing the document, so GetLastError still describes the
  // GDI call rather than whatever pdfium did last.
  const auto ended = EndDoc(hDC) > 0;
  const auto endError =
      ended ? std::string{}
            : lastErrorMessage("Unable to finish the print job");

  FPDF_CloseDocument(doc);

  if (!ended) {
    failJob(endError);
    return;
  }
  documentOpen = false;

  releaseHandles();

  printing->onCompleted(this, true, "");
}

void PrintJob::releaseHandles() {
  if (hDC) {
    DeleteDC(hDC);
    hDC = nullptr;
  }
  if (hDevNames) {
    GlobalFree(hDevNames);
    hDevNames = nullptr;
  }
  if (hDevMode) {
    GlobalFree(hDevMode);
    hDevMode = nullptr;
  }
}

/// End a job that never reached writeJob.
///
/// This was an empty body, so every failure path that could not print simply
/// dropped the job: the Dart side awaits onCompleted unconditionally, so its
/// future never settled and the printer HDC and DEVMODEs leaked.
void PrintJob::cancelJob(const std::string& error) {
  releaseHandles();
  printing->onCompleted(this, false, error);
}

/// End a job that failed while it was being spooled.
///
/// AbortDoc runs only when StartDoc actually opened a document, so no call is
/// made on a device context with nothing to abort.
void PrintJob::failJob(const std::string& error) {
  if (documentOpen) {
    AbortDoc(hDC);
    documentOpen = false;
  }
  releaseHandles();
  printing->onCompleted(this, false, error);
}

bool PrintJob::sharePdf(std::vector<uint8_t> data, const std::string& name) {
  TCHAR lpTempPathBuffer[MAX_PATH];

  auto ret = GetTempPath(MAX_PATH, lpTempPathBuffer);
  if (ret > MAX_PATH || (ret == 0)) {
    return false;
  }

  // Defensive basename: the name comes from Dart and used to be pasted into
  // the path as-is, so one carrying a separator wrote outside the temp
  // directory.
  auto basename = name.substr(name.find_last_of("/\\") + 1);
  if (basename.empty() || basename == "." || basename == "..") {
    basename = "document.pdf";
  }

  auto directory = toUtf8(lpTempPathBuffer);
  if (!directory.empty() && directory.back() != '\\') {
    directory += "\\";
  }
  auto filename = fromUtf8(directory + basename);

  auto output_file =
      std::basic_ofstream<uint8_t>{filename, std::ios::out | std::ios::binary};
  output_file.write(data.data(), data.size());
  output_file.close();
  if (!output_file) {
    // A full disk or an unwritable temp directory used to be reported as a
    // successful share.
    return false;
  }

  SHELLEXECUTEINFO ShExecInfo = {};
  ShExecInfo.cbSize = sizeof(SHELLEXECUTEINFO);
  ShExecInfo.fMask = 0;
  ShExecInfo.hwnd = nullptr;
  ShExecInfo.lpVerb = TEXT("open");
  ShExecInfo.lpFile = filename.c_str();
  ShExecInfo.lpParameters = nullptr;
  ShExecInfo.lpDirectory = nullptr;
  ShExecInfo.nShow = SW_SHOWDEFAULT;
  ShExecInfo.hInstApp = nullptr;

  ret = ShellExecuteEx(&ShExecInfo);

  return ret == TRUE;
}

void PrintJob::pickPrinter(void* result) {}

void PrintJob::rasterPdf(std::vector<uint8_t> data,
                         std::vector<int> pages,
                         double scale) {
  auto doc = FPDF_LoadMemDocument64(data.data(), data.size(), nullptr);
  if (!doc) {
    printing->onPageRasterEnd(this, "Cannot raster a malformed PDF file");
    return;
  }

  auto pageCount = FPDF_GetPageCount(doc);

  if (pages.size() == 0) {
    // Use all pages
    pages.resize(pageCount);
    std::iota(std::begin(pages), std::end(pages), 0);
  }

  for (auto n : pages) {
    if (n >= pageCount) {
      continue;
    }

    auto page = FPDF_LoadPage(doc, n);
    if (!page) {
      continue;
    }

    auto width = FPDF_GetPageWidth(page);
    auto height = FPDF_GetPageHeight(page);

    auto bWidth = static_cast<int>(width * scale);
    auto bHeight = static_cast<int>(height * scale);

    auto bitmap = FPDFBitmap_Create(bWidth, bHeight, 1);
    FPDFBitmap_FillRect(bitmap, 0, 0, bWidth, bHeight, 0x00ffffff);

    FPDF_RenderPageBitmap(bitmap, page, 0, 0, bWidth, bHeight, 0,
                          FPDF_ANNOT | FPDF_LCD_TEXT);

    uint8_t* p = static_cast<uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
    auto stride = FPDFBitmap_GetStride(bitmap);
    size_t l = static_cast<size_t>(bHeight * stride);

    // BGRA to RGBA conversion
    for (auto y = 0; y < bHeight; y++) {
      auto offset = y * stride;
      for (auto x = 0; x < bWidth; x++) {
        auto t = p[offset];
        p[offset] = p[offset + 2];
        p[offset + 2] = t;
        offset += 4;
      }
    }

    printing->onPageRasterized(std::vector<uint8_t>{p, p + l}, bWidth, bHeight,
                               this);

    FPDFBitmap_Destroy(bitmap);
    FPDF_ClosePage(page);
  }

  FPDF_CloseDocument(doc);

  printing->onPageRasterEnd(this, "");
}

std::map<std::string, bool> PrintJob::printingInfo() {
  return std::map<std::string, bool>{
      {"directPrint", true},     {"dynamicLayout", true}, {"canPrint", true},
      {"canListPrinters", true}, {"canShare", true},      {"canRaster", true},
  };
}

}  // namespace nfet
