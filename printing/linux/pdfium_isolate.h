// Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
// Licensed under the Apache License, Version 2.0.
//
// Linux printing must not share PDFium's mutable globals with pdfrx.
// PDFiumFunctions contains only pointers resolved from a dedicated glibc
// linker namespace, never symbols from the base ELF namespace.
#ifndef PRINTING_LINUX_PDFIUM_ISOLATE_H_
#define PRINTING_LINUX_PDFIUM_ISOLATE_H_

#include <fpdfview.h>

namespace printing_pdfium {

struct PDFiumFunctions {
  decltype(&FPDF_InitLibraryWithConfig) initialize = nullptr;
  decltype(&FPDF_DestroyLibrary) destroy = nullptr;
  decltype(&FPDF_LoadMemDocument64) load_document = nullptr;
  decltype(&FPDF_GetPageCount) page_count = nullptr;
  decltype(&FPDF_LoadPage) load_page = nullptr;
  decltype(&FPDF_GetPageWidth) page_width = nullptr;
  decltype(&FPDF_GetPageHeight) page_height = nullptr;
  decltype(&FPDFBitmap_Create) bitmap_create = nullptr;
  decltype(&FPDFBitmap_FillRect) bitmap_fill = nullptr;
  decltype(&FPDF_RenderPageBitmap) bitmap_render = nullptr;
  decltype(&FPDFBitmap_GetBuffer) bitmap_buffer = nullptr;
  decltype(&FPDFBitmap_GetStride) bitmap_stride = nullptr;
  decltype(&FPDFBitmap_Destroy) bitmap_destroy = nullptr;
  decltype(&FPDF_ClosePage) close_page = nullptr;
  decltype(&FPDF_CloseDocument) close_document = nullptr;
};

// Throws std::runtime_error when the private PDFium cannot be loaded.
// Callers catch the exception in the raster worker and notify Dart; never
// fall back to RTLD_DEFAULT or the application's libpdfium.so.
const PDFiumFunctions& functions();

}  // namespace printing_pdfium
#endif  // PRINTING_LINUX_PDFIUM_ISOLATE_H_
