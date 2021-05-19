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

#include "print_job.h"

#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <cstring>
#include <string>

#include <fpdfview.h>

print_job::print_job(int index) : index(index) {}

print_job::~print_job() {}

static gboolean add_printer(GtkPrinter* printer, gpointer data) {
  auto printers = static_cast<FlValue*>(data);

  auto map = fl_value_new_map();
  auto name = gtk_printer_get_name(printer);
  auto loc = gtk_printer_get_location(printer);
  auto cmt = gtk_printer_get_description(printer);

  fl_value_set_string(map, "url", fl_value_new_string(name));
  fl_value_set_string(map, "name", fl_value_new_string(name));
  if (loc) {
    fl_value_set_string(map, "location", fl_value_new_string(loc));
  }
  if (cmt) {
    fl_value_set_string(map, "comment", fl_value_new_string(cmt));
  }
  fl_value_set_string(map, "default",
                      fl_value_new_bool(gtk_printer_is_default(printer)));
  fl_value_set_string(map, "available",
                      fl_value_new_bool(gtk_printer_is_active(printer) &&
                                        gtk_printer_accepts_pdf(printer)));

  fl_value_append(printers, map);
  return false;
}

FlValue* print_job::list_printers() {
  auto printers = fl_value_new_list();
  gtk_enumerate_printers(add_printer, printers, nullptr, true);
  return printers;
}

static GtkPrinter* _printer;

static gboolean search_printer(GtkPrinter* printer, gpointer data) {
  auto search = static_cast<gchar*>(data);
  auto name = gtk_printer_get_name(printer);

  if (strcmp(name, search) == 0) {
    _printer = static_cast<GtkPrinter*>(g_object_ref(printer));
    return true;
  }

  return false;
}

bool print_job::direct_print_pdf(const gchar* name,
                                 const uint8_t data[],
                                 size_t size,
                                 const gchar* printer) {
  _printer = nullptr;
  auto pname = strdup(printer);
  gtk_enumerate_printers(search_printer, pname, nullptr, true);
  free(pname);

  if (!_printer) {
    return false;
  }

  auto settings = gtk_print_settings_new();
  auto setup = gtk_page_setup_new();
  printJob = gtk_print_job_new(name, _printer, settings, setup);
  this->write_job(data, size);

  g_object_unref(_printer);
  g_object_unref(settings);
  g_object_unref(setup);
  g_object_unref(printJob);

  return true;
}

static void job_completed(GtkPrintJob* gtk_print_job,
                          gpointer user_data,
                          const GError* error) {
  auto job = static_cast<print_job*>(user_data);
  on_completed(job, error == nullptr,
               error != nullptr ? error->message : nullptr);
}

bool print_job::print_pdf(const gchar* name,
                          const gchar* printer,
                          double pageWidth,
                          double pageHeight,
                          double marginLeft,
                          double marginTop,
                          double marginRight,
                          double marginBottom) {
  GtkPrintSettings* settings;
  GtkPageSetup* setup;

  if (printer != nullptr) {
    _printer = nullptr;
    auto pname = strdup(printer);
    gtk_enumerate_printers(search_printer, pname, nullptr, true);
    free(pname);

    if (!_printer) {
      on_completed(this, false, "Printer not found");
      return false;
    }

    settings = gtk_print_settings_new();
    setup = gtk_page_setup_new();

  } else {
    auto dialog =
        GTK_PRINT_UNIX_DIALOG(gtk_print_unix_dialog_new(name, nullptr));
    gtk_print_unix_dialog_set_manual_capabilities(
        dialog, (GtkPrintCapabilities)(GTK_PRINT_CAPABILITY_GENERATE_PDF));
    gtk_print_unix_dialog_set_embed_page_setup(dialog, true);
    gtk_print_unix_dialog_set_support_selection(dialog, false);

    gtk_widget_realize(GTK_WIDGET(dialog));

    auto loop = true;

    while (loop) {
      auto response = gtk_dialog_run(GTK_DIALOG(dialog));

      switch (response) {
        case GTK_RESPONSE_OK: {
          _printer = gtk_print_unix_dialog_get_selected_printer(
              GTK_PRINT_UNIX_DIALOG(dialog));
          settings =
              gtk_print_unix_dialog_get_settings(GTK_PRINT_UNIX_DIALOG(dialog));
          setup = gtk_print_unix_dialog_get_page_setup(
              GTK_PRINT_UNIX_DIALOG(dialog));
          gtk_widget_destroy(GTK_WIDGET(dialog));
          loop = false;
        } break;
        case GTK_RESPONSE_APPLY:  // Preview
          break;
        default:  // Cancel
          gtk_widget_destroy(GTK_WIDGET(dialog));
          on_completed(this, false, nullptr);
          return true;
      }
    }
  }

  if (!gtk_printer_accepts_pdf(_printer)) {
    on_completed(this, false, "This printer does not accept PDF jobs");
    g_object_unref(_printer);
    g_object_unref(settings);
    g_object_unref(setup);
    return false;
  }

  auto _width = gtk_page_setup_get_paper_width(setup, GTK_UNIT_POINTS);
  auto _height = gtk_page_setup_get_paper_height(setup, GTK_UNIT_POINTS);
  auto _marginLeft = gtk_page_setup_get_left_margin(setup, GTK_UNIT_POINTS);
  auto _marginTop = gtk_page_setup_get_top_margin(setup, GTK_UNIT_POINTS);
  auto _marginRight = gtk_page_setup_get_right_margin(setup, GTK_UNIT_POINTS);
  auto _marginBottom = gtk_page_setup_get_bottom_margin(setup, GTK_UNIT_POINTS);

  printJob = gtk_print_job_new(name, _printer, settings, setup);

  on_layout(this, _width, _height, _marginLeft, _marginTop, _marginRight,
            _marginBottom);

  g_object_unref(_printer);
  g_object_unref(settings);
  g_object_unref(setup);

  return true;
}

void print_job::write_job(const uint8_t data[], size_t size) {
  auto fd = memfd_create("printing", 0);
  size_t offset = 0;
  size_t n;
  while ((n = write(fd, data + offset, size - offset)) >= 0 &&
         size - offset > 0) {
    offset += n;
  }
  if (n < 0) {
    on_completed(this, false, "Unable to copy the PDF data");
  }

  lseek(fd, 0, SEEK_SET);

  gtk_print_job_set_source_fd(printJob, fd, nullptr);
  gtk_print_job_send(printJob, job_completed, this, nullptr);
}

void print_job::cancel_job(const gchar* error) {}

bool print_job::share_pdf(const uint8_t data[],
                          size_t size,
                          const gchar* name) {
  auto filename = "/tmp/" + std::string(name);

  auto fd = fopen(filename.c_str(), "wb");
  fwrite(data, size, 1, fd);
  fclose(fd);

  auto pid = fork();

  if (pid < 0) {  // error occurred
    return false;
  } else if (pid == 0) {  // child process
    execlp("xdg-open", "xdg-open", filename.c_str(), nullptr);
  }

  int status = 0;
  waitpid(pid, &status, 0);

  return status == 0;
}

void print_job::raster_pdf(const uint8_t data[],
                           size_t size,
                           const int32_t pages[],
                           size_t pages_count,
                           double scale) {
  FPDF_InitLibraryWithConfig(nullptr);

  auto doc = FPDF_LoadMemDocument64(data, size, nullptr);
  if (!doc) {
    FPDF_DestroyLibrary();
    on_page_raster_end(this, "Cannot raster a malformed PDF file");
    return;
  }

  auto pageCount = FPDF_GetPageCount(doc);
  auto allPages = false;

  if (pages_count == 0) {
    allPages = true;
    pages_count = pageCount;
  }

  for (auto pn = 0; pn < pages_count; pn++) {
    auto n = allPages ? pn : pages[pn];
    if (n >= pageCount) {
      continue;
    }

    auto page = FPDF_LoadPage(doc, n);
    if (!page) {
      continue;
    }

    auto width = FPDF_GetPageWidth(page);
    auto height = FPDF_GetPageHeight(page);

    auto bWidth = static_cast<int>(width * scale);
    auto bHeight = static_cast<int>(height * scale);

    auto bitmap = FPDFBitmap_Create(bWidth, bHeight, 0);
    FPDFBitmap_FillRect(bitmap, 0, 0, bWidth, bHeight, 0xffffffff);

    FPDF_RenderPageBitmap(bitmap, page, 0, 0, bWidth, bHeight, 0, FPDF_ANNOT);

    uint8_t* p = static_cast<uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
    auto stride = FPDFBitmap_GetStride(bitmap);
    size_t l = static_cast<size_t>(bHeight * stride);

    // BGRA to RGBA conversion
    for (auto y = 0; y < bHeight; y++) {
      auto offset = y * stride;
      for (auto x = 0; x < bWidth; x++) {
        auto t = p[offset];
        p[offset] = p[offset + 2];
        p[offset + 2] = t;
        offset += 4;
      }
    }

    on_page_rasterized(this, p, l, bWidth, bHeight);

    FPDFBitmap_Destroy(bitmap);
  }

  FPDF_CloseDocument(doc);

  FPDF_DestroyLibrary();

  on_page_raster_end(this, nullptr);
}

FlValue* print_job::printing_info() {
  FlValue* result = fl_value_new_map();
  fl_value_set_string(result, "canPrint", fl_value_new_bool(true));
  fl_value_set_string(result, "canShare", fl_value_new_bool(true));
  fl_value_set_string(result, "canRaster", fl_value_new_bool(true));
  fl_value_set_string(result, "canListPrinters", fl_value_new_bool(true));
  fl_value_set_string(result, "directPrint", fl_value_new_bool(true));
  fl_value_set_string(result, "dynamicLayout", fl_value_new_bool(true));
  return result;
}
