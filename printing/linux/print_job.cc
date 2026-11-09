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

#include <linux/memfd.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <limits>
#include <mutex>
#include <string>

#include <fpdfview.h>

// PDFium is a process-wide library: only the first job initializes it and
// only the last one destroys it.
static int library_ref_count = 0;
static std::mutex library_mutex;
// The Linux plugin used to raster on the GTK thread, which serialized PDFium
// accidentally. Background raster jobs must retain that process-wide ordering.
static std::mutex pdfium_work_mutex;

static void acquire_pdfium() {
  const std::lock_guard<std::mutex> lock{library_mutex};
  if (library_ref_count++ == 0) {
    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    FPDF_InitLibraryWithConfig(&config);
  }
}

static void release_pdfium() {
  const std::lock_guard<std::mutex> lock{library_mutex};
  if (--library_ref_count == 0) {
    FPDF_DestroyLibrary();
  }
}

print_job::print_job(FlMethodChannel* channel, int index)
    : channel(FL_METHOD_CHANNEL(g_object_ref(channel))), index(index) {}

print_job::~print_job() {
  if (dialog != nullptr) {
    gtk_widget_destroy(GTK_WIDGET(dialog));
    dialog = nullptr;
  }
  g_clear_object(&printJob);
  if (source_fd >= 0) {
    close(source_fd);
    source_fd = -1;
  }
  g_clear_object(&channel);
}

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

struct PrinterSearch {
  const gchar* name;
  GtkPrinter* result = nullptr;
};

static gboolean search_printer(GtkPrinter* printer, gpointer data) {
  auto search = static_cast<PrinterSearch*>(data);
  if (strcmp(gtk_printer_get_name(printer), search->name) == 0) {
    search->result = GTK_PRINTER(g_object_ref(printer));
    return TRUE;
  }
  return FALSE;
}

// The selected printer belongs to this invocation, not a process-wide global.
static GtkPrinter* find_printer(const gchar* name) {
  if (name == nullptr) {
    return nullptr;
  }
  PrinterSearch search{name};
  gtk_enumerate_printers(search_printer, &search, nullptr, TRUE);
  return search.result;
}

bool print_job::direct_print_pdf(const gchar* name,
                                 const uint8_t data[],
                                 size_t size,
                                 const gchar* printer) {
  auto selectedPrinter = find_printer(printer);
  if (selectedPrinter == nullptr) {
    return false;
  }

  auto settings = gtk_print_settings_new();
  auto setup = gtk_page_setup_new();
  printJob = gtk_print_job_new(name, selectedPrinter, settings, setup);
  const bool queued = this->write_job(data, size);

  g_object_unref(selectedPrinter);
  g_object_unref(settings);
  g_object_unref(setup);
  g_clear_object(&printJob);

  return queued;
}

static void job_completed(GtkPrintJob* gtk_print_job,
                          gpointer user_data,
                          const GError* error) {
  auto job = static_cast<print_job*>(user_data);
  if (job->dialog) {
    gtk_widget_destroy(GTK_WIDGET(job->dialog));
    job->dialog = nullptr;
  }
  on_completed(job, error == nullptr,
               error != nullptr ? error->message : nullptr);
  delete job;
}

bool print_job::print_pdf(const gchar* name,
                          const gchar* printer,
                          double pageWidth,
                          double pageHeight,
                          double marginLeft,
                          double marginTop,
                          double marginRight,
                          double marginBottom) {
  GtkPrintSettings* settings = nullptr;
  GtkPageSetup* setup = nullptr;
  GtkPrinter* selectedPrinter = nullptr;

  if (printer != nullptr) {
    selectedPrinter = find_printer(printer);
    if (selectedPrinter == nullptr) {
      on_completed(this, false, "Printer not found");
      return false;
    }

    settings = gtk_print_settings_new();
    setup = gtk_page_setup_new();

  } else {
    dialog = GTK_PRINT_UNIX_DIALOG(gtk_print_unix_dialog_new(name, nullptr));
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
          // GtkPrinter and GtkPageSetup are transfer-none, while settings
          // are newly allocated. Retain borrowed values before dialog teardown.
          auto borrowedPrinter = gtk_print_unix_dialog_get_selected_printer(
              GTK_PRINT_UNIX_DIALOG(dialog));
          selectedPrinter = borrowedPrinter != nullptr
                                ? GTK_PRINTER(g_object_ref(borrowedPrinter))
                                : nullptr;
          settings =
              gtk_print_unix_dialog_get_settings(GTK_PRINT_UNIX_DIALOG(dialog));
          auto borrowedSetup = gtk_print_unix_dialog_get_page_setup(
              GTK_PRINT_UNIX_DIALOG(dialog));
          setup = borrowedSetup != nullptr
                      ? GTK_PAGE_SETUP(g_object_ref(borrowedSetup))
                      : nullptr;
          gtk_widget_hide(GTK_WIDGET(dialog));
          loop = false;
        } break;
        case GTK_RESPONSE_APPLY:  // Preview
          break;
        default:  // Cancel
          gtk_widget_destroy(GTK_WIDGET(dialog));
          dialog = nullptr;
          on_completed(this, false, nullptr);
          // The method handler owns this job until print_pdf returns false.
          return false;
      }
    }
  }

  if (selectedPrinter == nullptr || settings == nullptr || setup == nullptr) {
    on_completed(this, false, "Printer or page setup is unavailable");
    g_clear_object(&selectedPrinter);
    g_clear_object(&settings);
    g_clear_object(&setup);
    return false;
  }

  if (!gtk_printer_accepts_pdf(selectedPrinter)) {
    on_completed(this, false, "This printer does not accept PDF jobs");
    g_object_unref(selectedPrinter);
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

  printJob = gtk_print_job_new(name, selectedPrinter, settings, setup);

  on_layout(this, _width, _height, _marginLeft, _marginTop, _marginRight,
            _marginBottom);

  g_object_unref(selectedPrinter);
  g_object_unref(settings);
  g_object_unref(setup);

  return true;
}

bool print_job::write_job(const uint8_t data[], size_t size) {
  if (printJob == nullptr || data == nullptr || size == 0) {
    on_completed(this, false, "Print job or PDF data is missing");
    return false;
  }

  const int fd = static_cast<int>(syscall(SYS_memfd_create, "printing", MFD_CLOEXEC));
  if (fd < 0) {
    on_completed(this, false, "Unable to create PDF spool file");
    return false;
  }

  size_t offset = 0;
  while (offset < size) {
    const ssize_t written = write(fd, data + offset, size - offset);
    if (written < 0 && errno == EINTR) {
      continue;
    }
    if (written <= 0) {
      close(fd);
      on_completed(this, false, "Unable to copy the PDF data");
      return false;
    }
    offset += static_cast<size_t>(written);
  }

  if (lseek(fd, 0, SEEK_SET) < 0) {
    close(fd);
    on_completed(this, false, "Unable to rewind PDF spool file");
    return false;
  }

  g_autoptr(GError) source_error = nullptr;
  if (!gtk_print_job_set_source_fd(printJob, fd, &source_error)) {
    close(fd);
    on_completed(this, false,
                 source_error != nullptr ? source_error->message
                                         : "Unable to attach PDF spool file");
    return false;
  }

  // gtk_print_job_set_source_fd wraps the descriptor without closing it on
  // GIOChannel unref. The completion callback deletes this job, closing fd.
  source_fd = fd;
  gtk_print_job_send(printJob, job_completed, this, nullptr);
  return true;
}

void print_job::cancel_job(const gchar* error) {
  if (dialog) {
    gtk_widget_destroy(GTK_WIDGET(dialog));
    dialog = nullptr;
  }
  g_clear_object(&printJob);
  on_completed(this, false, error);
}

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
  const std::lock_guard<std::mutex> work_lock{pdfium_work_mutex};
  acquire_pdfium();

  auto doc = FPDF_LoadMemDocument64(data, size, nullptr);
  if (!doc) {
    release_pdfium();
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
    if (n < 0 || n >= pageCount) {
      continue;
    }

    auto page = FPDF_LoadPage(doc, n);
    if (!page) {
      continue;
    }

    auto width = FPDF_GetPageWidth(page);
    auto height = FPDF_GetPageHeight(page);

    const double pixelWidth = width * scale;
    const double pixelHeight = height * scale;
    if (!std::isfinite(pixelWidth) || !std::isfinite(pixelHeight) ||
        pixelWidth < 1.0 || pixelHeight < 1.0 ||
        pixelWidth > std::numeric_limits<int>::max() ||
        pixelHeight > std::numeric_limits<int>::max()) {
      FPDF_ClosePage(page);
      FPDF_CloseDocument(doc);
      release_pdfium();
      on_page_raster_end(this, "Invalid raster dimensions");
      return;
    }
    const auto bWidth = static_cast<int>(pixelWidth);
    const auto bHeight = static_cast<int>(pixelHeight);

    auto bitmap = FPDFBitmap_Create(bWidth, bHeight, 1);
    if (bitmap == nullptr) {
      FPDF_ClosePage(page);
      FPDF_CloseDocument(doc);
      release_pdfium();
      on_page_raster_end(this, "Unable to allocate raster bitmap");
      return;
    }
    FPDFBitmap_FillRect(bitmap, 0, 0, bWidth, bHeight, 0x00ffffff);

    FPDF_RenderPageBitmap(bitmap, page, 0, 0, bWidth, bHeight, 0,
                          FPDF_ANNOT | FPDF_LCD_TEXT | FPDF_NO_NATIVETEXT);

    uint8_t* p = static_cast<uint8_t*>(FPDFBitmap_GetBuffer(bitmap));
    const int stride = FPDFBitmap_GetStride(bitmap);
    // Check both the minimum RGBA row size and multiplication *before*
    // calculating the image length. The old int multiplication could overflow.
    if (p == nullptr || stride <= 0 ||
        static_cast<size_t>(stride) < static_cast<size_t>(bWidth) * 4u ||
        static_cast<size_t>(bHeight) >
            std::numeric_limits<size_t>::max() / static_cast<size_t>(stride)) {
      FPDFBitmap_Destroy(bitmap);
      FPDF_ClosePage(page);
      FPDF_CloseDocument(doc);
      release_pdfium();
      on_page_raster_end(this, "Invalid PDFium raster buffer");
      return;
    }
    const size_t l = static_cast<size_t>(bHeight) *
                     static_cast<size_t>(stride);

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
    FPDF_ClosePage(page);
  }

  FPDF_CloseDocument(doc);

  release_pdfium();

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
