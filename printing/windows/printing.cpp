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

#include "print_job.h"

namespace nfet {

std::mutex Printing::pdfiumMutex;

static const wchar_t kPlatformWindowClass[] = L"NfetPrintingPlatformWindow";

// PDFium is a process-wide library: only the first instance initializes it and
// only the last one destroys it.
static int libraryRefCount = 0;
static std::mutex libraryMutex;

Printing::Printing(flutter::MethodChannel<flutter::EncodableValue>* channel,
                   flutter::PluginRegistrarWindows* registrar)
    : channel{channel},
      registrar{registrar},
      platformThreadId{GetCurrentThreadId()} {
  const std::lock_guard<std::mutex> lock{libraryMutex};
  if (libraryRefCount++ == 0) {
    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    FPDF_InitLibraryWithConfig(&config);
  }
}

Printing::~Printing() {
  if (worker.joinable()) {
    {
      const std::lock_guard<std::mutex> lock{workerMutex};
      workerStopping = true;
    }
    workerCondition.notify_one();
    // Lets queued jobs finish; their callbacks are dropped with the window.
    worker.join();
  }

  if (platformWindow) {
    DestroyWindow(platformWindow);
  }

  const std::lock_guard<std::mutex> lock{libraryMutex};
  if (--libraryRefCount == 0) {
    FPDF_DestroyLibrary();
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

void Printing::runOnWorker(std::function<void()> task) {
  if (!worker.joinable()) {
    WNDCLASS windowClass{};
    windowClass.lpfnWndProc = platformWindowProc;
    windowClass.hInstance = GetModuleHandle(nullptr);
    windowClass.lpszClassName = kPlatformWindowClass;
    RegisterClass(&windowClass);  // Fails harmlessly if already registered.

    platformWindow =
        CreateWindow(kPlatformWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                     nullptr, windowClass.hInstance, nullptr);
    SetWindowLongPtr(platformWindow, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(this));

    worker = std::thread{&Printing::runWorker, this};
  }

  {
    const std::lock_guard<std::mutex> lock{workerMutex};
    workerTasks.push_back(std::move(task));
  }
  workerCondition.notify_one();
}

void Printing::runWorker() {
  for (;;) {
    std::function<void()> task;
    {
      std::unique_lock<std::mutex> lock{workerMutex};
      workerCondition.wait(
          lock, [this] { return workerStopping || !workerTasks.empty(); });
      if (workerTasks.empty()) {
        return;
      }
      task = std::move(workerTasks.front());
      workerTasks.pop_front();
    }
    task();
  }
}

void Printing::runOnPlatform(std::function<void()> task) {
  if (GetCurrentThreadId() == platformThreadId) {
    task();
    return;
  }

  {
    const std::lock_guard<std::mutex> lock{platformMutex};
    platformTasks.push_back(std::move(task));
  }
  PostMessage(platformWindow, WM_APP, 0, 0);
}

void Printing::runPlatformTasks() {
  std::deque<std::function<void()>> tasks;
  {
    const std::lock_guard<std::mutex> lock{platformMutex};
    tasks.swap(platformTasks);
  }
  for (auto& task : tasks) {
    task();
  }
}

LRESULT CALLBACK Printing::platformWindowProc(HWND hwnd,
                                              UINT message,
                                              WPARAM wparam,
                                              LPARAM lparam) {
  if (message == WM_APP) {
    auto printing =
        reinterpret_cast<Printing*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (printing) {
      printing->runPlatformTasks();
    }
    return 0;
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

void Printing::invokeMethod(const std::string& method,
                            flutter::EncodableValue arguments) {
  runOnPlatform([this, method, arguments = std::move(arguments)] {
    channel->InvokeMethod(method,
                          std::make_unique<flutter::EncodableValue>(arguments));
  });
}

void Printing::onPageRasterized(std::vector<uint8_t> data,
                                int width,
                                int height,
                                PrintJob* job) {
  invokeMethod(
      "onPageRasterized",
      flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("image"),
           flutter::EncodableValue(std::move(data))},
          {flutter::EncodableValue("width"), flutter::EncodableValue(width)},
          {flutter::EncodableValue("height"), flutter::EncodableValue(height)},
          {flutter::EncodableValue("job"), flutter::EncodableValue(job->id())},
      }));
}

void Printing::onPageRasterEnd(PrintJob* job, const std::string& error) {
  auto map = flutter::EncodableMap{
      {flutter::EncodableValue("job"), flutter::EncodableValue(job->id())},
  };

  if (!error.empty()) {
    map[flutter::EncodableValue("error")] = flutter::EncodableValue(error);
  }

  invokeMethod("onPageRasterEnd", flutter::EncodableValue(map));
}

class OnLayoutResult : public flutter::MethodResult<flutter::EncodableValue> {
 public:
  OnLayoutResult(Printing* printing, PrintJob* job)
      : printing{printing}, job{job} {}

 private:
  Printing* printing;
  PrintJob* job;

 protected:
  void SuccessInternal(const flutter::EncodableValue* result) {
    auto doc = std::get<std::vector<uint8_t>>(*result);

    printing->runOnWorker([job = job, doc = std::move(doc)] {
      job->writeJob(doc);
      delete job;
    });
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
                        std::make_unique<OnLayoutResult>(this, job));
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

  invokeMethod("onCompleted", flutter::EncodableValue(map));
}

}  // namespace nfet
