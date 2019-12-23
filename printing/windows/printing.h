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

#include <map>
#include <memory>
#include <sstream>
#include <vector>

#include <flutter/method_channel.h>

// #include "print_job.h"

namespace nfet {

class PrintJob;

class Printing {
 private:
 public:
  Printing();

  virtual ~Printing();

  void onPageRasterized(std::vector<uint8_t> data,
                        int width,
                        int height,
                        PrintJob* job);

  void onPageRasterEnd(PrintJob* job);

  void onLayout(PrintJob* job,
                double pageWidth,
                double pageHeight,
                double marginLeft,
                double marginTop,
                double marginRight,
                double marginBottom);
};

}  // namespace nfet

#endif  // PRINTING_PLUGIN_PRINTING_H_
