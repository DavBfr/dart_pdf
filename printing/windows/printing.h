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

#ifndef PRINTING_PLUGIN_PRINTING_H_
#define PRINTING_PLUGIN_PRINTING_H_

#include <windows.h>

#include <condition_variable>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <thread>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

namespace nfet {

class PrintJob;

class Printing {
 private:
  flutter::MethodChannel<flutter::EncodableValue>* channel;
  flutter::PluginRegistrarWindows* registrar;

  std::thread worker;
  std::mutex workerMutex;
  std::condition_variable workerCondition;
  std::deque<std::function<void()>> workerTasks;
  bool workerStopping = false;

  DWORD platformThreadId;
  HWND platformWindow = nullptr;
  std::mutex platformMutex;
  std::deque<std::function<void()>> platformTasks;

  void runWorker();

  void runPlatformTasks();

  // Callbacks may come from the print thread; the channel is platform-only.
  void invokeMethod(const std::string& method,
                    flutter::EncodableValue arguments);

  static LRESULT CALLBACK platformWindowProc(HWND hwnd,
                                             UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam);

 public:
  // Serializes PDFium calls: PDFium is not thread-safe.
  static std::mutex pdfiumMutex;

  Printing(flutter::MethodChannel<flutter::EncodableValue>* channel,
           flutter::PluginRegistrarWindows* registrar);

  virtual ~Printing();

  // Top-level window of the engine owning this plugin instance, or nullptr.
  // Resolved on demand: the view is reparented after plugin registration.
  HWND getWindow();

  // Runs task on this instance's print thread, which is started on first use.
  // Must be called from the platform thread.
  void runOnWorker(std::function<void()> task);

  // Runs task on the platform thread, immediately if already there.
  void runOnPlatform(std::function<void()> task);

  void onPageRasterized(std::vector<uint8_t> data,
                        int width,
                        int height,
                        PrintJob* job);

  void onPageRasterEnd(PrintJob* job, const std::string& error);

  void onLayout(PrintJob* job,
                double pageWidth,
                double pageHeight,
                double marginLeft,
                double marginTop,
                double marginRight,
                double marginBottom);

  void onCompleted(PrintJob* job, bool completed, const std::string& error);
};

}  // namespace nfet

#endif  // PRINTING_PLUGIN_PRINTING_H_
