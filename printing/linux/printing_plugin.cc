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

#include "include/printing/printing_plugin.h"

#include <atomic>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include "print_job.h"
#include "raster_dispatch.h"

#define PRINTING_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), printing_plugin_get_type(), \
                              PrintingPlugin))

struct _PrintingPlugin {
  GObject parent_instance;

  FlMethodChannel* channel;
  GThreadPool* raster_pool;
  // Ref-counted because a native raster task may outlive plugin disposal.
  std::shared_ptr<std::atomic<int>>* raster_inflight;
};

G_DEFINE_TYPE(PrintingPlugin, printing_plugin, g_object_get_type())

struct RasterTask {
  std::unique_ptr<print_job> job;
  std::vector<uint8_t> document;
  std::vector<int32_t> pages;
  std::shared_ptr<std::atomic<int>> raster_inflight;
  double scale;

  ~RasterTask() {
    if (raster_inflight) {
      raster_inflight->fetch_sub(1, std::memory_order_release);
    }
  }
};

// One executing raster and at most one queued request. This bounds the number
// of retained PDF documents without rejecting a large *single* document.
static constexpr int kMaxOutstandingRasterRequests = 2;
static bool reserve_raster_slot(const std::shared_ptr<std::atomic<int>>& counter) {
  int count = counter->load(std::memory_order_acquire);
  while (count < kMaxOutstandingRasterRequests) {
    if (counter->compare_exchange_weak(
            count, count + 1, std::memory_order_acq_rel)) {
      return true;
    }
  }
  return false;
}

static gboolean keep_raster_task(gpointer data) {
  (void)data;
  return G_SOURCE_REMOVE;
}

static void release_raster_task(gpointer data) {
  delete static_cast<RasterTask*>(data);
}

static void raster_task_run(gpointer data, gpointer user_data) {
  (void)user_data;
  std::unique_ptr<RasterTask> task(static_cast<RasterTask*>(data));
  try {
    task->job->raster_pdf(
        task->document.data(), task->document.size(),
        task->pages.empty() ? nullptr : task->pages.data(), task->pages.size(),
        task->scale);
  } catch (const std::exception& error) {
    on_page_raster_end(task->job.get(), error.what());
  } catch (...) {
    on_page_raster_end(task->job.get(), "Raster worker failed");
  }
  std::vector<uint8_t>().swap(task->document);
  // The job may hold the last channel reference after engine shutdown, and
  // disposing FlMethodChannel off the GTK thread touches the messenger.
  printing_raster::post_message(keep_raster_task, task.release(),
                                release_raster_task);
}

// Called when a method call is received from Flutter.
static void printing_plugin_handle_method_call(PrintingPlugin* self,
                                               FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "printingInfo") == 0) {
    g_autoptr(FlValue) result = print_job::printing_info();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else if (strcmp(method, "listPrinters") == 0) {
    g_autoptr(FlValue) result = print_job::list_printers();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else if (strcmp(method, "printPdf") == 0) {
    auto name = fl_value_get_string(fl_value_lookup_string(args, "name"));
    auto printerValue = fl_value_lookup_string(args, "printer");
    auto printer =
        printerValue == nullptr ? nullptr : fl_value_get_string(printerValue);
    auto jobNum = fl_value_get_int(fl_value_lookup_string(args, "job"));
    auto pageWidth = fl_value_get_float(fl_value_lookup_string(args, "width"));
    auto pageHeight =
        fl_value_get_float(fl_value_lookup_string(args, "height"));
    auto marginLeft =
        fl_value_get_float(fl_value_lookup_string(args, "marginLeft"));
    auto marginTop =
        fl_value_get_float(fl_value_lookup_string(args, "marginTop"));
    auto marginRight =
        fl_value_get_float(fl_value_lookup_string(args, "marginRight"));
    auto marginBottom =
        fl_value_get_float(fl_value_lookup_string(args, "marginBottom"));

    auto job = new print_job(self->channel, jobNum);
    auto res = job->print_pdf(name, printer, pageWidth, pageHeight, marginLeft,
                              marginTop, marginRight, marginBottom);
    if (!res) {
      delete job;
    }
    g_autoptr(FlValue) result = fl_value_new_int(res);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else if (strcmp(method, "sharePdf") == 0) {
    auto name = fl_value_get_string(fl_value_lookup_string(args, "name"));
    auto doc = fl_value_get_uint8_list(fl_value_lookup_string(args, "doc"));
    auto size = fl_value_get_length(fl_value_lookup_string(args, "doc"));

    auto res = print_job::share_pdf(doc, size, name);
    g_autoptr(FlValue) result = fl_value_new_int(res);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else if (strcmp(method, "rasterPdf") == 0) {
    auto doc_value = fl_value_lookup_string(args, "doc");
    if (doc_value == nullptr ||
        fl_value_get_type(doc_value) != FL_VALUE_TYPE_UINT8_LIST ||
        fl_value_get_length(doc_value) == 0) {
      // Empty or malformed document arguments must not be passed through
      // pointer arithmetic into the native raster task.
      auto job_value = fl_value_lookup_string(args, "job");
      if (job_value != nullptr &&
          fl_value_get_type(job_value) == FL_VALUE_TYPE_INT) {
        auto failed_job = std::make_unique<print_job>(
            self->channel, fl_value_get_int(job_value));
        on_page_raster_end(failed_job.get(), "PDF document is empty or invalid");
      }
      g_autoptr(FlValue) result = fl_value_new_bool(false);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      fl_method_call_respond(method_call, response, nullptr);
      return;
    }
    auto doc = fl_value_get_uint8_list(doc_value);
    auto size = fl_value_get_length(doc_value);
    auto v_pages = fl_value_lookup_string(args, "pages");
    std::vector<int32_t> pages;
    if (v_pages != nullptr && fl_value_get_type(v_pages) == FL_VALUE_TYPE_LIST) {
      const auto pages_count = fl_value_get_length(v_pages);
      pages.reserve(pages_count);
      for (size_t n = 0; n < pages_count; n++) {
        pages.push_back(
            static_cast<int32_t>(fl_value_get_int(fl_value_get_list_value(v_pages, n))));
      }
    }
    auto scale = fl_value_get_float(fl_value_lookup_string(args, "scale"));
    auto jobNum = fl_value_get_int(fl_value_lookup_string(args, "job"));

    g_autoptr(GError) worker_error = nullptr;
    if (self->raster_pool == nullptr) {
      self->raster_pool =
          printing_raster::create_pool(raster_task_run, &worker_error);
    }
    bool queued = false;
    if (self->raster_pool != nullptr &&
        reserve_raster_slot(*self->raster_inflight)) {
      auto task = std::make_unique<RasterTask>();
      task->raster_inflight = *self->raster_inflight;
      task->job = std::make_unique<print_job>(self->channel, jobNum);
      task->document.assign(doc, doc + size);
      task->pages = std::move(pages);
      task->scale = scale;

      // The exclusive pool already owns its worker; enqueue cannot spawn one.
      g_thread_pool_push(self->raster_pool, task.release(), nullptr);
      queued = true;
    } else {
      auto failed_job = std::make_unique<print_job>(self->channel, jobNum);
      on_page_raster_end(
          failed_job.get(),
          self->raster_pool == nullptr
              ? (worker_error != nullptr ? worker_error->message
                                         : "Raster worker is unavailable")
              : "Raster queue is full");
    }

    g_autoptr(FlValue) result = fl_value_new_bool(queued);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void printing_plugin_dispose(GObject* object) {
  auto self = PRINTING_PLUGIN(object);
  if (self->raster_pool != nullptr) {
    // Do not join native PDFium work on the GTK/UI thread. Each queued task
    // owns its input, channel reference and admission counter; callbacks post
    // to the main context and may safely arrive after plugin disposal.
    g_thread_pool_free(self->raster_pool, FALSE, FALSE);
    self->raster_pool = nullptr;
  }
  delete self->raster_inflight;
  self->raster_inflight = nullptr;
  G_OBJECT_CLASS(printing_plugin_parent_class)->dispose(object);
}

static void printing_plugin_class_init(PrintingPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = printing_plugin_dispose;
}

static void printing_plugin_init(PrintingPlugin* self) {
  self->raster_inflight =
      new std::shared_ptr<std::atomic<int>>(std::make_shared<std::atomic<int>>(0));
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  PrintingPlugin* plugin = PRINTING_PLUGIN(user_data);
  printing_plugin_handle_method_call(plugin, method_call);
}

void printing_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  PrintingPlugin* plugin =
      PRINTING_PLUGIN(g_object_new(printing_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  // The messenger keeps the channel alive for the engine's lifetime and the
  // channel keeps the plugin; the plugin only borrows the channel pointer.
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "net.nfet.printing", FL_METHOD_CODEC(codec));
  plugin->channel = channel;
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}

struct RasterPageMessage {
  FlMethodChannel* channel;
  int job;
  std::vector<uint8_t> image;
  int width;
  int height;
};

static gboolean deliver_raster_page(gpointer data) {
  auto message = static_cast<RasterPageMessage*>(data);
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(
      map, "image",
      fl_value_new_uint8_list(message->image.data(), message->image.size()));
  fl_value_set_string(map, "width", fl_value_new_int(message->width));
  fl_value_set_string(map, "height", fl_value_new_int(message->height));
  fl_value_set_string(map, "job", fl_value_new_int(message->job));
  fl_method_channel_invoke_method(message->channel, "onPageRasterized", map,
                                  nullptr, nullptr, nullptr);
  return G_SOURCE_REMOVE;
}

static void destroy_raster_page(gpointer data) {
  std::unique_ptr<RasterPageMessage> message(
      static_cast<RasterPageMessage*>(data));
  g_object_unref(message->channel);
}

void on_page_rasterized(print_job* job,
                        const uint8_t* data,
                        size_t size,
                        int width,
                        int height) {
  auto message = std::make_unique<RasterPageMessage>();
  message->channel =
      FL_METHOD_CHANNEL(g_object_ref(job->get_channel()));
  message->job = job->get_id();
  message->image.assign(data, data + size);
  message->width = width;
  message->height = height;
  printing_raster::post_message(deliver_raster_page, message.release(),
                                destroy_raster_page);
}

struct RasterEndMessage {
  FlMethodChannel* channel;
  int job;
  std::string error;
  bool has_error;
};

static gboolean deliver_raster_end(gpointer data) {
  auto message = static_cast<RasterEndMessage*>(data);
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "job", fl_value_new_int(message->job));
  if (message->has_error) {
    fl_value_set_string(map, "error", fl_value_new_string(message->error.c_str()));
  }
  fl_method_channel_invoke_method(message->channel, "onPageRasterEnd", map,
                                  nullptr, nullptr, nullptr);
  return G_SOURCE_REMOVE;
}

static void destroy_raster_end(gpointer data) {
  std::unique_ptr<RasterEndMessage> message(
      static_cast<RasterEndMessage*>(data));
  g_object_unref(message->channel);
}

void on_page_raster_end(print_job* job, const char* error) {
  auto message = std::make_unique<RasterEndMessage>();
  message->channel =
      FL_METHOD_CHANNEL(g_object_ref(job->get_channel()));
  message->job = job->get_id();
  message->has_error = error != nullptr;
  if (error != nullptr) {
    message->error = error;
  }
  printing_raster::post_message(deliver_raster_end, message.release(),
                                destroy_raster_end);
}

static void on_layout_response_cb(GObject* object,
                                  GAsyncResult* result,
                                  gpointer user_data) {
  print_job* job = static_cast<print_job*>(user_data);
  FlMethodChannel* channel = job->get_channel();
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response =
      fl_method_channel_invoke_method_finish(channel, result, &error);
  if (!response) {
    job->cancel_job(error != nullptr ? error->message : "Layout callback failed");
    delete job;
    return;
  }

  if (FL_IS_METHOD_SUCCESS_RESPONSE(response)) {
    FlValue* result = fl_method_success_response_get_result(
        FL_METHOD_SUCCESS_RESPONSE(response));
    if (result == nullptr ||
        fl_value_get_type(result) != FL_VALUE_TYPE_UINT8_LIST) {
      job->cancel_job("Layout callback did not provide PDF bytes");
      delete job;
      return;
    }
    auto data = fl_value_get_uint8_list(result);
    auto size = fl_value_get_length(result);
    if (!job->write_job(data, size)) {
      delete job;
    }
  } else if (FL_IS_METHOD_ERROR_RESPONSE(response)) {
    FlMethodErrorResponse* error_response = FL_METHOD_ERROR_RESPONSE(response);
    // fl_method_error_response_get_code(error_response);
    auto message = fl_method_error_response_get_message(error_response);
    //  fl_method_error_response_get_details(error_response);
    job->cancel_job(message);
    delete job;
  } else {
    job->cancel_job("Unsupported layout callback response");
    delete job;
  }
}

void on_layout(print_job* job,
               double pageWidth,
               double pageHeight,
               double marginLeft,
               double marginTop,
               double marginRight,
               double marginBottom) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "job", fl_value_new_int(job->get_id()));
  fl_value_set_string(map, "width", fl_value_new_float(pageWidth));
  fl_value_set_string(map, "height", fl_value_new_float(pageHeight));
  fl_value_set_string(map, "marginLeft", fl_value_new_float(marginLeft));
  fl_value_set_string(map, "marginTop", fl_value_new_float(marginTop));
  fl_value_set_string(map, "marginRight", fl_value_new_float(marginRight));
  fl_value_set_string(map, "marginBottom", fl_value_new_float(marginBottom));

  fl_method_channel_invoke_method(job->get_channel(), "onLayout", map, nullptr,
                                  on_layout_response_cb, job);
}

void on_completed(print_job* job, bool completed, const char* error) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "job", fl_value_new_int(job->get_id()));
  fl_value_set_string(map, "completed", fl_value_new_bool(completed));
  if (error != nullptr) {
    fl_value_set_string(map, "error", fl_value_new_string(error));
  }

  fl_method_channel_invoke_method(job->get_channel(), "onCompleted", map,
                                  nullptr, nullptr, nullptr);
}
