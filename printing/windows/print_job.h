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

class PrintJob {
 private:
  Printing* printing;
  int index;
  HGLOBAL hDevMode = nullptr;
  HGLOBAL hDevNames = nullptr;
  HDC hDC = nullptr;

 public:
  PrintJob(Printing* printing, int index);

  // ~PrintJob() { printf("Delete PrintJob #%d\n", index); }

  int id() { return index; }

  void directPrintPdf(std::string name,
                      std::vector<uint8_t> data,
                      std::string withPrinter);

  bool printPdf(std::string name);

  void writeJob(std::vector<uint8_t> data);

  void cancelJob(std::string error);

  bool sharePdf(std::vector<uint8_t> data, std::string name);

  void pickPrinter(void* result);

  void rasterPdf(std::vector<uint8_t> data,
                 std::vector<int> pages,
                 double scale);

  std::map<std::string, bool> printingInfo();
};

}  // namespace nfet

#endif  // PRINTING_PLUGIN_PRINT_JOB_H_
