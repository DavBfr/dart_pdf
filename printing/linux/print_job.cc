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

#include "pdfium_raster.h"

#include <errno.h>
#include <linux/memfd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cstring>
#include <mutex>
#include <string>

#include <fpdfview.h>

// PDFium is a process-wide library: only the first job initializes it and
// only the last one destroys it.
static int library_ref_count = 0;
static std::mutex library_mutex;

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
    : channel(channel), index(index) {}

print_job::~print_job() {
  release();
}

void print_job::release() {
  if (dialog != nullptr) {
    // Destroyed, not hidden: a hidden dialog stays alive and keeps answering
    // backend signals.
    gtk_widget_destroy(GTK_WIDGET(dialog));
    dialog = nullptr;
  }

  if (printJob != nullptr) {
    g_object_unref(printJob);
    printJob = nullptr;
  }

  if (spool_fd >= 0) {
    close(spool_fd);
    spool_fd = -1;
  }
}

void print_job::finish(bool completed, const gchar* error) {
  if (is_completed) {
    // A second result - a backend that reports twice, or a failure on a path
    // that has already reported - must not reach Dart, where it used to raise
    // 'Bad state: Future already completed'.
    return;
  }
  is_completed = true;

  release();
  on_completed(this, completed, error);

  if (owns_self) {
    delete this;
  }
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

struct printer_search {
  const gchar* name;
  GtkPrinter* found;
};

static gboolean search_printer(GtkPrinter* printer, gpointer data) {
  auto search = static_cast<printer_search*>(data);
  auto name = gtk_printer_get_name(printer);

  if (name != nullptr && strcmp(name, search->name) == 0) {
    search->found = static_cast<GtkPrinter*>(g_object_ref(printer));
    return true;
  }

  return false;
}

/// Look a printer up by name, transfer full, or nullptr when there is none.
static GtkPrinter* find_printer(const gchar* name) {
  if (name == nullptr) {
    return nullptr;
  }

  printer_search search{name, nullptr};
  gtk_enumerate_printers(search_printer, &search, nullptr, true);
  return search.found;
}

bool print_job::direct_print_pdf(const gchar* name,
                                 const uint8_t data[],
                                 size_t size,
                                 const gchar* printer) {
  auto target = find_printer(printer);

  if (target == nullptr) {
    // This used to return without reporting anything, leaving the Dart future
    // pending for ever.
    finish(false, "Printer not found");
    return false;
  }

  auto settings = gtk_print_settings_new();
  auto setup = gtk_page_setup_new();
  printJob = gtk_print_job_new(name, target, settings, setup);
  g_object_unref(target);
  g_object_unref(settings);
  g_object_unref(setup);

  // From here the job reports its own result, so it owns itself. printJob is
  // released by finish(); gtk_print_job_send takes its own reference.
  owns_self = true;
  write_job(data, size);
  return true;
}

static void job_completed(GtkPrintJob* gtk_print_job,
                          gpointer user_data,
                          const GError* error) {
  auto job = static_cast<print_job*>(user_data);
  job->finish(error == nullptr, error != nullptr ? error->message : nullptr);
}

bool print_job::print_pdf(const gchar* name,
                          const gchar* printer,
                          double pageWidth,
                          double pageHeight,
                          double marginLeft,
                          double marginTop,
                          double marginRight,
                          double marginBottom) {
  // Every one of these is transfer full, on both branches, so both exit paths
  // can unref unconditionally. Two of the three dialog getters below are
  // transfer none, and unreffing those dropped references this function never
  // took.
  GtkPrinter* target = nullptr;
  GtkPrintSettings* settings = nullptr;
  GtkPageSetup* setup = nullptr;

  if (printer != nullptr) {
    target = find_printer(printer);

    if (target == nullptr) {
      finish(false, "Printer not found");
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
          // transfer none
          auto selected = gtk_print_unix_dialog_get_selected_printer(
              GTK_PRINT_UNIX_DIALOG(dialog));
          if (selected == nullptr) {
            finish(false, "No printer selected");
            return false;
          }
          target = static_cast<GtkPrinter*>(g_object_ref(selected));
          // transfer full
          settings =
              gtk_print_unix_dialog_get_settings(GTK_PRINT_UNIX_DIALOG(dialog));
          // transfer none
          auto page_setup = gtk_print_unix_dialog_get_page_setup(
              GTK_PRINT_UNIX_DIALOG(dialog));
          setup = page_setup != nullptr
                      ? static_cast<GtkPageSetup*>(g_object_ref(page_setup))
                      : gtk_page_setup_new();
          gtk_widget_hide(GTK_WIDGET(dialog));
          loop = false;
        } break;
        case GTK_RESPONSE_APPLY:  // Preview
          break;
        default:  // Cancel
          // false, so the plugin reclaims the job; returning true leaked one
          // job per cancel.
          finish(false, nullptr);
          return false;
      }
    }
  }

  if (!gtk_printer_accepts_pdf(target)) {
    g_object_unref(target);
    g_object_unref(settings);
    g_object_unref(setup);
    finish(false, "This printer does not accept PDF jobs");
    return false;
  }

  auto _width = gtk_page_setup_get_paper_width(setup, GTK_UNIT_POINTS);
  auto _height = gtk_page_setup_get_paper_height(setup, GTK_UNIT_POINTS);
  auto _marginLeft = gtk_page_setup_get_left_margin(setup, GTK_UNIT_POINTS);
  auto _marginTop = gtk_page_setup_get_top_margin(setup, GTK_UNIT_POINTS);
  auto _marginRight = gtk_page_setup_get_right_margin(setup, GTK_UNIT_POINTS);
  auto _marginBottom = gtk_page_setup_get_bottom_margin(setup, GTK_UNIT_POINTS);

  printJob = gtk_print_job_new(name, target, settings, setup);

  g_object_unref(target);
  g_object_unref(settings);
  g_object_unref(setup);

  // From here the job reports its own result, so it owns itself.
  owns_self = true;
  on_layout(this, _width, _height, _marginLeft, _marginTop, _marginRight,
            _marginBottom);

  return true;
}

void print_job::write_job(const uint8_t data[], size_t size) {
  if (printJob == nullptr) {
    finish(false, "No print job to write to");
    return;
  }

  // Owned by this job from here on, and closed exactly once in release(). The
  // GIOChannel gtk_print_job_set_source_fd wraps it in has close_on_unref
  // FALSE, so nothing else ever closed it: every print leaked one fd and one
  // PDF-sized memfd.
  spool_fd = static_cast<int>(syscall(SYS_memfd_create, "printing", 0));
  if (spool_fd < 0) {
    finish(false, "Unable to create the print spool");
    return;
  }

  size_t offset = 0;
  while (offset < size) {
    const auto n = write(spool_fd, data + offset, size - offset);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      // Returning here is what stops a truncated document from being sent to
      // the printer, and stops a second completion reaching Dart.
      finish(false, "Unable to copy the PDF data");
      return;
    }
    if (n == 0) {
      finish(false, "Unable to copy the PDF data");
      return;
    }
    offset += static_cast<size_t>(n);
  }

  if (lseek(spool_fd, 0, SEEK_SET) != 0) {
    finish(false, "Unable to rewind the print spool");
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!gtk_print_job_set_source_fd(printJob, spool_fd, &error)) {
    finish(false,
           error != nullptr ? error->message : "Unable to spool the document");
    return;
  }

  gtk_print_job_send(printJob, job_completed, this, nullptr);
}

void print_job::cancel_job(const gchar* error) {
  // A nullptr error means cancelled, which Dart completes as false. This used
  // to be an empty body, so a failed onLayout left the future pending, the
  // dialog hidden and everything the job owned alive.
  finish(false, error);
}

bool print_job::share_pdf(const uint8_t data[],
                          size_t size,
                          const gchar* name) {
  // Defensive basename: a name carrying a separator used to point at a
  // directory that does not exist, and fopen then returned NULL, which the
  // unchecked fwrite below turned into a crash of the whole application.
  std::string base = name == nullptr ? "" : std::string(name);
  const auto slash = base.find_last_of("/\\");
  if (slash != std::string::npos) {
    base = base.substr(slash + 1);
  }
  if (base.empty() || base == "." || base == "..") {
    base = "document.pdf";
  }

  const auto filename = "/tmp/" + base;

  auto fd = fopen(filename.c_str(), "wb");
  if (!fd) {
    return false;
  }
  const auto written = size == 0 ? 0 : fwrite(data, size, 1, fd);
  const auto closed = fclose(fd);
  if ((size != 0 && written != 1) || closed != 0) {
    remove(filename.c_str());
    return false;
  }

  auto pid = fork();

  if (pid < 0) {  // error occurred
    return false;
  } else if (pid == 0) {  // child process
    execlp("xdg-open", "xdg-open", filename.c_str(), nullptr);
    // Only reached when exec failed. Without this the child returns into the
    // Flutter engine and a second copy of the whole application keeps running.
    _exit(EXIT_FAILURE);
  }

  int status = 0;
  waitpid(pid, &status, 0);

  return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

/// Holds the process-wide pdfium reference for a scope.
class pdfium_scope {
 public:
  pdfium_scope() { acquire_pdfium(); }
  ~pdfium_scope() { release_pdfium(); }

  pdfium_scope(const pdfium_scope&) = delete;
  pdfium_scope& operator=(const pdfium_scope&) = delete;
};

/// Closes a pdfium handle however the scope is left.
///
/// The raster loop gained exit paths that must not skip FPDF_ClosePage,
/// FPDFBitmap_Destroy or the library reference.
template <typename Handle, void (*Close)(Handle)>
class pdfium_handle {
 public:
  explicit pdfium_handle(Handle handle) : handle_(handle) {}
  ~pdfium_handle() {
    if (handle_ != nullptr) {
      Close(handle_);
    }
  }

  pdfium_handle(const pdfium_handle&) = delete;
  pdfium_handle& operator=(const pdfium_handle&) = delete;

  Handle get() const { return handle_; }
  explicit operator bool() const { return handle_ != nullptr; }

 private:
  Handle handle_;
};

using document_handle = pdfium_handle<FPDF_DOCUMENT, &FPDF_CloseDocument>;
using page_handle = pdfium_handle<FPDF_PAGE, &FPDF_ClosePage>;
using bitmap_handle = pdfium_handle<FPDF_BITMAP, &FPDFBitmap_Destroy>;

void print_job::raster_pdf(const uint8_t data[],
                           size_t size,
                           const int32_t pages[],
                           size_t pages_count,
                           double scale,
                           uint32_t background) {
  const pdfium_scope pdfium;

  document_handle doc{FPDF_LoadMemDocument64(data, size, nullptr)};
  if (!doc) {
    on_page_raster_end(this, "Cannot raster a malformed PDF file");
    return;
  }

  auto pageCount = FPDF_GetPageCount(doc.get());
  auto allPages = false;

  if (pages_count == 0) {
    allPages = true;
    pages_count = pageCount;
  }

  for (size_t pn = 0; pn < pages_count; pn++) {
    auto n = allPages ? static_cast<int32_t>(pn) : pages[pn];
    if (n >= pageCount) {
      continue;
    }

    page_handle page{FPDF_LoadPage(doc.get(), n)};
    if (!page) {
      continue;
    }

    const auto raster = nfet::rasterSizeFor(
        FPDF_GetPageWidth(page.get()), FPDF_GetPageHeight(page.get()), scale);
    if (!raster.valid) {
      // pdfium answers a null bitmap for this, which the loop below used to
      // write through.
      on_page_raster_end(this, "Cannot raster a page this large");
      return;
    }

    bitmap_handle bitmap{FPDFBitmap_Create(raster.width, raster.height, 1)};
    if (!bitmap) {
      on_page_raster_end(this, "Out of memory rastering a page");
      return;
    }

    // A PDF page has no background of its own. This used to be hard-coded to
    // 0x00ffffff, which writes white but leaves alpha at 0, so a rastered page
    // came back transparent and saving it as PNG gave a black page.
    FPDFBitmap_FillRect(bitmap.get(), 0, 0, raster.width, raster.height,
                        static_cast<unsigned long>(background));

    FPDF_RenderPageBitmap(bitmap.get(), page.get(), 0, 0, raster.width,
                          raster.height, 0,
                          FPDF_ANNOT | FPDF_LCD_TEXT | FPDF_NO_NATIVETEXT);

    uint8_t* p = static_cast<uint8_t*>(FPDFBitmap_GetBuffer(bitmap.get()));
    if (p == nullptr) {
      on_page_raster_end(this, "Unable to read the rastered page");
      return;
    }

    nfet::bgraToPremultipliedRgba(p, raster.width, raster.height,
                                  raster.stride);

    on_page_rasterized(this, p, raster.bytes, raster.width, raster.height);
  }

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
