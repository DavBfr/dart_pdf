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

#include "printing.h"

#include "print_job.h"

namespace nfet {

extern std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;

Printing::Printing() {}

Printing::~Printing() {}

PrintJob* Printing::createJob(int num) {
  return new PrintJob{this, num};
}

void Printing::remove(PrintJob* job) {
  delete job;
}

void Printing::onPageRasterized(std::vector<uint8_t> data,
                                int width,
                                int height,
                                PrintJob* job) {
  channel->InvokeMethod(
      "onPageRasterized",
      std::make_unique<flutter::EncodableValue>(
          flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("image"), flutter::EncodableValue(data)},
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(width)},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(height)},
              {flutter::EncodableValue("job"),
               flutter::EncodableValue(job->id())},
          })));
}

void Printing::onPageRasterEnd(PrintJob* job) {
  channel->InvokeMethod("onPageRasterEnd",
                        std::make_unique<flutter::EncodableValue>(
                            flutter::EncodableValue(flutter::EncodableMap{
                                {flutter::EncodableValue("job"),
                                 flutter::EncodableValue(job->id())},
                            })));
}

class OnLayoutResult : public flutter::MethodResult<flutter::EncodableValue> {
 public:
  OnLayoutResult(PrintJob* job_) : job(job_) {
    n = 90;
    printf("OnLayoutResult (%d) %p\n", job->id(), this);
  }

  OnLayoutResult(const OnLayoutResult& other) {
    job = other.job;
    printf("OnLayoutResult copy (%d) %p\n", job->id(), this);
  }

  OnLayoutResult(const OnLayoutResult&& other) {
    job = other.job;
    printf("OnLayoutResult move (%d) %p\n", job->id(), this);
  }

  ~OnLayoutResult() {
    printf("OnLayoutResult delete (%d) %p\n", job->id(), this);
  }

 private:
  PrintJob* job;
  int n = 0;

 protected:
  void SuccessInternal(const flutter::EncodableValue* result) {
    auto doc = std::get<std::vector<uint8_t>>(*result);
    printf("Success! n:%d (%d) %llu bytes %p\n", n, job->id(), doc.size(),
           this);
    job->writeJob(doc);
  }

  void ErrorInternal(const std::string& error_code,
                     const std::string& error_message,
                     const flutter::EncodableValue* error_details) {
    printf("Error!\n");
  }

  void NotImplementedInternal() { printf("NotImplemented!\n"); }
};

void Printing::onLayout(PrintJob* job,
                        double pageWidth,
                        double pageHeight,
                        double marginLeft,
                        double marginTop,
                        double marginRight,
                        double marginBottom) {
  printf("onLayout (%d) %fx%f %f %f %f %f\n", job->id(), pageWidth, pageHeight,
         marginLeft, marginTop, marginRight, marginBottom);

  // auto result = std::make_unique<OnLayoutResult>(job);

  channel->InvokeMethod("onLayout",
                        std::make_unique<flutter::EncodableValue>(
                            flutter::EncodableValue(flutter::EncodableMap{
                                {flutter::EncodableValue("job"),
                                 flutter::EncodableValue(job->id())},
                                {flutter::EncodableValue("width"),
                                 flutter::EncodableValue(pageWidth)},
                                {flutter::EncodableValue("height"),
                                 flutter::EncodableValue(pageHeight)},
                                {flutter::EncodableValue("marginLeft"),
                                 flutter::EncodableValue(marginLeft)},
                                {flutter::EncodableValue("marginTop"),
                                 flutter::EncodableValue(marginTop)},
                                {flutter::EncodableValue("marginRight"),
                                 flutter::EncodableValue(marginRight)},
                                {flutter::EncodableValue("marginBottom"),
                                 flutter::EncodableValue(marginBottom)},
                            })),
                        std::make_unique<OnLayoutResult>(job));
}

}  // namespace nfet
