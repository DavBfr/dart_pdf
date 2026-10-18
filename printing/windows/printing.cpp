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

#include "printing.h"

#include <fpdfview.h>

#include <mutex>
#include <string>

#include <delayimp.h>

#include "print_job.h"

// pdfium.dll is delay-loaded from the plugin's directory under a private name:
// a pdfium.dll loaded by the application is a separate module and its global
// state is not shared with this plugin.
static FARPROC WINAPI loadPrivatePdfium(unsigned notify, PDelayLoadInfo info) {
  if (notify != dliNotePreLoadLibrary || _stricmp(info->szDll, "pdfium.dll")) {
    return nullptr;
  }

  HMODULE module = nullptr;
  wchar_t path[MAX_PATH];
  if (!GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(&loadPrivatePdfium),
                         &module) ||
      !GetModuleFileName(module, path, MAX_PATH)) {
    return nullptr;
  }

  auto file = std::wstring{path};
  file = file.substr(0, file.find_last_of(L'\\') + 1) + L"pdfium_printing.dll";
  return reinterpret_cast<FARPROC>(
      LoadLibraryEx(file.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH));
}

extern "C" const PfnDliHook __pfnDliNotifyHook2 = loadPrivatePdfium;

namespace nfet {

// PDFium is a process-wide library: it is initialized on first use and
// destroyed with the last instance, only if this plugin initialized it.
static int libraryRefCount = 0;
static bool libraryInitialized = false;
static std::mutex libraryMutex;

Printing::Printing(flutter::MethodChannel<flutter::EncodableValue>* channel,
                   flutter::PluginRegistrarWindows* registrar)
    : channel{channel}, registrar{registrar} {
  const std::lock_guard<std::mutex> lock{libraryMutex};
  libraryRefCount++;
}

Printing::~Printing() {
  const std::lock_guard<std::mutex> lock{libraryMutex};
  if (--libraryRefCount == 0 && libraryInitialized) {
    FPDF_DestroyLibrary();
    libraryInitialized = false;
  }
}

void Printing::initLibrary() {
  const std::lock_guard<std::mutex> lock{libraryMutex};
  if (!libraryInitialized) {
    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    FPDF_InitLibraryWithConfig(&config);
    libraryInitialized = true;
  }
}

HWND Printing::getWindow() {
  auto* view = registrar->GetView();
  if (!view) {
    return nullptr;
  }
  HWND hwnd = view->GetNativeWindow();
  return hwnd ? GetAncestor(hwnd, GA_ROOT) : nullptr;
}

void Printing::onPageRasterized(std::vector<uint8_t> data,
                                int width,
                                int height,
                                PrintJob* job) {
  channel->InvokeMethod(
      "onPageRasterized",
      std::make_unique<flutter::EncodableValue>(
          flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("image"), flutter::EncodableValue(data)},
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(width)},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(height)},
              {flutter::EncodableValue("job"),
               flutter::EncodableValue(job->id())},
          })));
}

void Printing::onPageRasterEnd(PrintJob* job, const std::string& error) {
  auto map = flutter::EncodableMap{
      {flutter::EncodableValue("job"), flutter::EncodableValue(job->id())},
  };

  if (!error.empty()) {
    map[flutter::EncodableValue("error")] = flutter::EncodableValue(error);
  }

  channel->InvokeMethod(
      "onPageRasterEnd",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(map)));
}

class OnLayoutResult : public flutter::MethodResult<flutter::EncodableValue> {
 public:
  OnLayoutResult(PrintJob* job) : job{job} {}

 private:
  PrintJob* job;

 protected:
  void SuccessInternal(const flutter::EncodableValue* result) {
    auto doc = std::get<std::vector<uint8_t>>(*result);

    job->writeJob(doc);
    delete job;
  }

  void ErrorInternal(const std::string& error_code,
                     const std::string& error_message,
                     const flutter::EncodableValue* error_details) {
    delete job;
  }

  void NotImplementedInternal() { delete job; }
};

void Printing::onLayout(PrintJob* job,
                        double pageWidth,
                        double pageHeight,
                        double marginLeft,
                        double marginTop,
                        double marginRight,
                        double marginBottom) {
  channel->InvokeMethod("onLayout",
                        std::make_unique<flutter::EncodableValue>(
                            flutter::EncodableValue(flutter::EncodableMap{
                                {flutter::EncodableValue("job"),
                                 flutter::EncodableValue(job->id())},
                                {flutter::EncodableValue("width"),
                                 flutter::EncodableValue(pageWidth)},
                                {flutter::EncodableValue("height"),
                                 flutter::EncodableValue(pageHeight)},
                                {flutter::EncodableValue("marginLeft"),
                                 flutter::EncodableValue(marginLeft)},
                                {flutter::EncodableValue("marginTop"),
                                 flutter::EncodableValue(marginTop)},
                                {flutter::EncodableValue("marginRight"),
                                 flutter::EncodableValue(marginRight)},
                                {flutter::EncodableValue("marginBottom"),
                                 flutter::EncodableValue(marginBottom)},
                            })),
                        std::make_unique<OnLayoutResult>(job));
}

// send completion status to flutter
void Printing::onCompleted(PrintJob* job,
                           bool completed,
                           const std::string& error) {
  auto map = flutter::EncodableMap{
      {flutter::EncodableValue("job"), flutter::EncodableValue(job->id())},
      {flutter::EncodableValue("completed"),
       flutter::EncodableValue(completed)},
  };

  if (!error.empty()) {
    map[flutter::EncodableValue("error")] = flutter::EncodableValue(error);
  }

  channel->InvokeMethod(
      "onCompleted",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(map)));
}

}  // namespace nfet
