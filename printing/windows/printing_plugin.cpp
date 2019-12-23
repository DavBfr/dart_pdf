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

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

#include "print_job.h"
#include "printing.h"

namespace nfet {

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;

class PrintingPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar) {
    channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "net.nfet.printing",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<PrintingPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  PrintingPlugin() {}

  virtual ~PrintingPlugin() {}

 private:
  Printing printing{};
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name().compare("printPdf") == 0) {
      const auto* arguments =
          std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto vName = arguments->find(flutter::EncodableValue("name"));
      auto name = vName != arguments->end()
                      ? std::get<std::string>(vName->second)
                      : std::string{};
      auto vJob = arguments->find(flutter::EncodableValue("job"));
      auto jobNum = vJob != arguments->end() ? std::get<int>(vJob->second) : -1;
      auto job = new PrintJob{&printing, jobNum};
      auto res = job->printPdf(name);
      if (!res) {
        delete job;
      }
      result->Success(flutter::EncodableValue(res ? 1 : 0));
    } else if (method_call.method_name().compare("directPrintPdf") == 0) {
      auto job = std::make_unique<PrintJob>(&printing, -1);
      job->directPrintPdf("name", std::vector<uint8_t>{}, "withPrinter");
      result->Success(nullptr);
    } else if (method_call.method_name().compare("sharePdf") == 0) {
      const auto* arguments =
          std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto vName = arguments->find(flutter::EncodableValue("name"));
      auto name = vName != arguments->end()
                      ? std::get<std::string>(vName->second)
                      : std::string{"document.pdf"};
      auto vDoc = arguments->find(flutter::EncodableValue("doc"));
      auto doc = vDoc != arguments->end()
                     ? std::get<std::vector<uint8_t>>(vDoc->second)
                     : std::vector<uint8_t>{};
      auto job = std::make_unique<PrintJob>(&printing, -1);
      auto res = job->sharePdf(doc, name);
      result->Success(flutter::EncodableValue(res ? 1 : 0));
    } else if (method_call.method_name().compare("pickPrinter") == 0) {
      auto job = std::make_unique<PrintJob>(&printing, -1);
      job->pickPrinter(nullptr);
      result->Success(nullptr);
    } else if (method_call.method_name().compare("rasterPdf") == 0) {
      const auto* arguments =
          std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto vDoc = arguments->find(flutter::EncodableValue("doc"));
      auto doc = vDoc != arguments->end()
                     ? std::get<std::vector<uint8_t>>(vDoc->second)
                     : std::vector<uint8_t>{};
      //     auto vPages = arguments->find(flutter::EncodableValue("pages"));
      //     auto pages = vPages != arguments->end()
      //                      ? std::get<flutter
      //                      ::EncodableList>(vPages->second) : flutter
      //                      ::EncodableList{};
      auto vScale = arguments->find(flutter::EncodableValue("scale"));
      auto scale =
          vScale != arguments->end() ? std::get<double>(vScale->second) : 1;
      auto vJob = arguments->find(flutter::EncodableValue("job"));
      auto jobNum = vJob != arguments->end() ? std::get<int>(vJob->second) : -1;
      auto job = std::make_unique<PrintJob>(&printing, jobNum);
      job->rasterPdf(doc, std::vector<int>{}, scale);
      result->Success(nullptr);
    } else if (method_call.method_name().compare("printingInfo") == 0) {
      auto job = std::make_unique<PrintJob>(&printing, -1);
      auto map = flutter::EncodableMap{};
      for (auto item : job->printingInfo()) {
        map[flutter::EncodableValue(item.first)] =
            flutter::EncodableValue(item.second);
      }
      result->Success(map);
    } else {
      result->NotImplemented();
    }
  }
};

}  // namespace nfet

void PrintingPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  nfet::PrintingPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
