// Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
// Licensed under the Apache License, Version 2.0.

#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include "pdfium_isolate.h"

#include <dlfcn.h>
#include <link.h>

#include <memory>
#include <stdexcept>
#include <string>

namespace printing_pdfium {
namespace {

constexpr const char* kPrivateLibraryName = "libpdfium_printing.so";

// Resolve against this plugin's own directory, not the current working
// directory or LD_LIBRARY_PATH. Both files are placed in the Flutter bundle's
// lib/ directory by the Linux printing CMakeLists.txt.
std::string private_library_path() {
  Dl_info info = {};
  if (dladdr(reinterpret_cast<const void*>(&functions), &info) == 0 ||
      info.dli_fname == nullptr) {
    throw std::runtime_error("Cannot locate Linux printing plugin library");
  }

  const std::string plugin_path(info.dli_fname);
  const auto separator = plugin_path.find_last_of('/');
  if (separator == std::string::npos) {
    throw std::runtime_error("Linux printing plugin path is not absolute");
  }
  return plugin_path.substr(0, separator + 1) + kPrivateLibraryName;
}

void* required_symbol(void* handle, const char* name) {
  dlerror();
  void* symbol = dlsym(handle, name);
  const char* error = dlerror();
  if (symbol == nullptr || error != nullptr) {
    throw std::runtime_error(std::string("Private printing PDFium missing ") +
                             name + ": " +
                             (error != nullptr ? error : "symbol not found"));
  }
  return symbol;
}

PDFiumFunctions* load_isolated_pdfium() {
#if !defined(LM_ID_NEWLM) || !defined(__GLIBC__)
#error "Linux printing PDFium isolation requires glibc dlmopen"
#endif
  const auto path = private_library_path();
  // A new link-map namespace prevents both FPDF globals and ELF symbol
  // interposition between printing's Chromium 5200 and pdfrx's 8125. A
  // renamed SONAME or a second dlopen in LM_ID_BASE would not suffice.
  void* handle = dlmopen(LM_ID_NEWLM, path.c_str(), RTLD_NOW | RTLD_LOCAL);
  if (handle == nullptr) {
    const char* error = dlerror();
    throw std::runtime_error(std::string("Cannot load private printing PDFium: ") +
                             (error != nullptr ? error : "unknown dlmopen error"));
  }

  auto api = std::make_unique<PDFiumFunctions>();
  try {
#define RESOLVE(name, field)                                                    \
    api->field = reinterpret_cast<decltype(api->field)>(required_symbol(handle, #name))
    RESOLVE(FPDF_InitLibraryWithConfig, initialize);
    RESOLVE(FPDF_DestroyLibrary, destroy);
    RESOLVE(FPDF_LoadMemDocument64, load_document);
    RESOLVE(FPDF_GetPageCount, page_count);
    RESOLVE(FPDF_LoadPage, load_page);
    RESOLVE(FPDF_GetPageWidth, page_width);
    RESOLVE(FPDF_GetPageHeight, page_height);
    RESOLVE(FPDFBitmap_Create, bitmap_create);
    RESOLVE(FPDFBitmap_FillRect, bitmap_fill);
    RESOLVE(FPDF_RenderPageBitmap, bitmap_render);
    RESOLVE(FPDFBitmap_GetBuffer, bitmap_buffer);
    RESOLVE(FPDFBitmap_GetStride, bitmap_stride);
    RESOLVE(FPDFBitmap_Destroy, bitmap_destroy);
    RESOLVE(FPDF_ClosePage, close_page);
    RESOLVE(FPDF_CloseDocument, close_document);
#undef RESOLVE
  } catch (...) {
    dlclose(handle);
    throw;
  }

  // This namespace intentionally stays loaded for the process lifetime:
  // other printing workers and their callbacks may still be active when
  // GObject instances are finalized. PDFium's API initialize/destroy calls
  // are separately serialized within print_job.cc.
  return api.release();
}
}  // namespace

const PDFiumFunctions& functions() {
  static const PDFiumFunctions* const api = load_isolated_pdfium();
  return *api;
}

}  // namespace printing_pdfium
