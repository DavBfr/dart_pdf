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

/// A single print, raster or share request.
///
/// Ownership: the plugin creates the job and owns it until print_pdf or
/// direct_print_pdf returns true. From then on the job owns itself and
/// destroys itself in finish(), which is why nothing may touch a job after a
/// call that may finish it.
class print_job {
 private:
  // Not owned: belongs to the plugin instance this job was created by.
  FlMethodChannel* channel;
  const int index;
  GtkPrintJob* printJob = nullptr;
  GtkPrintUnixDialog* dialog = nullptr;
  // The memfd the document is spooled through. Owned by this job, because
  // gtk_print_job_set_source_fd wraps it in a GIOChannel that does not close
  // it.
  int spool_fd = -1;
  // Whether a terminal result has already been reported.
  bool is_completed = false;
  // Whether this job owns itself; see finish().
  bool owns_self = false;

  /// Destroy the dialog, drop the GtkPrintJob and close the spool fd.
  ///
  /// Idempotent, so the destructor can call it too.
  void release();

 public:
  print_job(FlMethodChannel* channel, int index);

  ~print_job();

  int get_id() { return index; };

  FlMethodChannel* get_channel() { return channel; };

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

  /// Report this job's single terminal result and release what it owns.
  ///
  /// Calls after the first are ignored, so every failure path can report
  /// without checking. Destroys the job when it owns itself: nothing may
  /// touch the job afterwards.
  void finish(bool completed, const gchar* error);

  /// Terminate the job with an error, or with nullptr for a cancellation.
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
