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

#include <memory>

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include "print_job.h"

#define PRINTING_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), printing_plugin_get_type(), \
                              PrintingPlugin))

struct _PrintingPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(PrintingPlugin, printing_plugin, g_object_get_type())

static FlMethodChannel* channel;

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

    auto job = new print_job(jobNum);
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
    auto doc = fl_value_get_uint8_list(fl_value_lookup_string(args, "doc"));
    auto size = fl_value_get_length(fl_value_lookup_string(args, "doc"));
    auto v_pages = fl_value_lookup_string(args, "pages");
    int32_t* pages = nullptr;
    size_t pages_count = 0;
    if (fl_value_get_type(v_pages) == FL_VALUE_TYPE_LIST) {
      pages_count = fl_value_get_length(v_pages);
      pages = (int32_t*)malloc(sizeof(int32_t) * pages_count);
      for (auto n = 0; n < pages_count; n++) {
        pages[n] = fl_value_get_int(fl_value_get_list_value(v_pages, n));
      }
    }
    auto scale = fl_value_get_float(fl_value_lookup_string(args, "scale"));
    auto jobNum = fl_value_get_int(fl_value_lookup_string(args, "job"));
    auto job = std::make_unique<print_job>(jobNum);
    job->raster_pdf(doc, size, pages, pages_count, scale);
    free(pages);

    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));

  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void printing_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(printing_plugin_parent_class)->dispose(object);
}

static void printing_plugin_class_init(PrintingPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = printing_plugin_dispose;
}

static void printing_plugin_init(PrintingPlugin* self) {}

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
  channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                  "net.nfet.printing", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}

void on_page_rasterized(print_job* job,
                        const uint8_t* data,
                        size_t size,
                        int width,
                        int height) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "image", fl_value_new_uint8_list(data, size));
  fl_value_set_string(map, "width", fl_value_new_int(width));
  fl_value_set_string(map, "height", fl_value_new_int(height));
  fl_value_set_string(map, "job", fl_value_new_int(job->get_id()));

  fl_method_channel_invoke_method(channel, "onPageRasterized", map, nullptr,
                                  nullptr, nullptr);
}

void on_page_raster_end(print_job* job, const char* error) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "job", fl_value_new_int(job->get_id()));
  if (error != nullptr) {
    fl_value_set_string(map, "error", fl_value_new_string(error));
  }

  fl_method_channel_invoke_method(channel, "onPageRasterEnd", map, nullptr,
                                  nullptr, nullptr);
}

static void on_layout_response_cb(GObject* object,
                                  GAsyncResult* result,
                                  gpointer user_data) {
  print_job* job = static_cast<print_job*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response =
      fl_method_channel_invoke_method_finish(channel, result, &error);
  if (!response) {
    job->cancel_job(error->message);
  }

  if (FL_IS_METHOD_SUCCESS_RESPONSE(response)) {
    FlValue* result = fl_method_success_response_get_result(
        FL_METHOD_SUCCESS_RESPONSE(response));
    auto data = fl_value_get_uint8_list(result);
    auto size = fl_value_get_length(result);
    job->write_job(data, size);
  } else if (FL_IS_METHOD_ERROR_RESPONSE(response)) {
    FlMethodErrorResponse* error_response = FL_METHOD_ERROR_RESPONSE(response);
    // fl_method_error_response_get_code(error_response);
    auto message = fl_method_error_response_get_message(error_response);
    //  fl_method_error_response_get_details(error_response);
    job->cancel_job(message);
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

  fl_method_channel_invoke_method(channel, "onLayout", map, nullptr,
                                  on_layout_response_cb, job);
}

void on_completed(print_job* job, bool completed, const char* error) {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string(map, "job", fl_value_new_int(job->get_id()));
  fl_value_set_string(map, "completed", fl_value_new_bool(completed));
  if (error != nullptr) {
    fl_value_set_string(map, "error", fl_value_new_string(error));
  }

  fl_method_channel_invoke_method(channel, "onCompleted", map, nullptr, nullptr,
                                  nullptr);
}
