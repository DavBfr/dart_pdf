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

#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gtk/gtkunixprint.h>

class print_job {
 private:
  const int index;
  GtkPrintJob* printJob;

 public:
  GtkPrintUnixDialog* dialog = nullptr;

  explicit print_job(int index);

  ~print_job();

  int get_id() { return index; };

  static FlValue* list_printers();

  bool direct_print_pdf(const gchar* name,
                        const uint8_t data[],
                        size_t size,
                        const gchar* printer);

  bool print_pdf(const gchar* name,
                 const gchar* printer,
                 double pageWidth,
                 double pageHeight,
                 double marginLeft,
                 double marginTop,
                 double marginRight,
                 double marginBottom);

  void write_job(const uint8_t data[], size_t size);

  void cancel_job(const gchar* error);

  static bool share_pdf(const uint8_t data[], size_t size, const gchar* name);

  void raster_pdf(const uint8_t data[],
                  size_t size,
                  const int32_t pages[],
                  size_t pages_count,
                  double scale);

  static FlValue* printing_info();
};

void on_page_rasterized(print_job* job,
                        const uint8_t* data,
                        size_t size,
                        int width,
                        int height);

void on_page_raster_end(print_job* job, const char* error);

void on_layout(print_job* job,
               double pageWidth,
               double pageHeight,
               double marginLeft,
               double marginTop,
               double marginRight,
               double marginBottom);

void on_completed(print_job* job, bool completed, const char* error);

#endif  // PRINTING_PLUGIN_PRINT_JOB_H_
