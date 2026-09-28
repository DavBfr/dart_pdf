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

#ifndef PRINTING_PLUGIN_PRINT_JOB_H_
#define PRINTING_PLUGIN_PRINT_JOB_H_

#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <map>
#include <memory>
#include <sstream>
#include <vector>

namespace nfet {

class Printing;

struct Printer {
  const std::string name;
  const std::string url;
  const std::string model;
  const std::string location;
  const std::string comment;
  const bool default;
  const bool available;

  Printer(const std::string& name,
          const std::string& url,
          const std::string& model,
          const std::string& location,
          const std::string& comment,
          bool default,
          bool available)
      : name(name),
        url(url),
        model(model),
        location(location),
        comment(comment),
        default(default),
        available(available) {}
};

class PrintJob {
 private:
  Printing* printing;
  int index;
  HGLOBAL hDevMode = nullptr;
  HGLOBAL hDevNames = nullptr;
  HDC hDC = nullptr;
  std::string documentName;
  // Whether StartDoc has opened a document that AbortDoc still has to close.
  bool documentOpen = false;

  /// Abort any open document, release the handles and report one failure.
  void failJob(const std::string& error);

 public:
  PrintJob(Printing* printing, int index);

  int id() { return index; }

  /// Enumerate the installed printers.
  ///
  /// On failure the result is empty and error holds a message, so a stopped
  /// spooler is reported instead of looking like a machine with no printers.
  std::vector<Printer> listPrinters(std::string* error);

  bool printPdf(const std::string& name,
                std::string printer,
                double width,
                double height,
                bool usePrinterSettings,
                bool windowsModernDialog);

  void writeJob(std::vector<uint8_t> data);

  void cancelJob(const std::string& error);

  // Release the printer device context and the DEVMODE/DEVNAMES blocks.
  // Idempotent, so a job may be cancelled after a partial setup.
  void releaseHandles();

  bool sharePdf(std::vector<uint8_t> data, const std::string& name);

  void pickPrinter(void* result);

  void rasterPdf(std::vector<uint8_t> data,
                 std::vector<int> pages,
                 double scale,
                 uint32_t background);

  std::map<std::string, bool> printingInfo();
};

}  // namespace nfet

#endif  // PRINTING_PLUGIN_PRINT_JOB_H_
