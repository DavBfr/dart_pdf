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

#import "PrintingPlugin.h"
#import "PageRenderer.h"

@implementation PrintingPlugin {
  FlutterMethodChannel* channel;
  PdfPrintPageRenderer* renderer;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel =
      [FlutterMethodChannel methodChannelWithName:@"printing"
                                  binaryMessenger:[registrar messenger]];
  PrintingPlugin* instance = [[PrintingPlugin alloc] init:channel];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init:(FlutterMethodChannel*)channel {
  self = [super init];
  self->channel = channel;
  self->renderer = [[PdfPrintPageRenderer alloc] init:channel];
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"printPdf" isEqualToString:call.method]) {
    [self printPdf:[call.arguments objectForKey:@"name"]];
    result(@1);
  } else if ([@"writePdf" isEqualToString:call.method]) {
    [self writePdf:[call.arguments objectForKey:@"doc"]];
    result(@1);
  } else if ([@"sharePdf" isEqualToString:call.method]) {
    [self sharePdf:[call.arguments objectForKey:@"doc"]
        withSourceRect:CGRectMake(
                           [[call.arguments objectForKey:@"x"] floatValue],
                           [[call.arguments objectForKey:@"y"] floatValue],
                           [[call.arguments objectForKey:@"w"] floatValue],
                           [[call.arguments objectForKey:@"h"] floatValue])];
    result(@1);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)printPdf:(nonnull NSString*)name {
  BOOL printing = [UIPrintInteractionController isPrintingAvailable];
  if (!printing) {
    NSLog(@"printing not available");
    return;
  }

  UIPrintInteractionController* controller =
      [UIPrintInteractionController sharedPrintController];
  [controller setDelegate:self];

  UIPrintInfo* printInfo = [UIPrintInfo printInfo];
  printInfo.jobName = name;
  printInfo.outputType = UIPrintInfoOutputGeneral;
  controller.printInfo = printInfo;
  [controller setPrintPageRenderer:renderer];
  UIPrintInteractionCompletionHandler completionHandler =
      ^(UIPrintInteractionController* printController, BOOL completed,
        NSError* error) {
        if (!completed && error) {
          NSLog(@"FAILED! due to error in domain %@ with error code %u",
                error.domain, (unsigned int)error.code);
        }
        if (self->renderer.pdfDocument != nil) {
          CGPDFDocumentRelease(self->renderer.pdfDocument);
          self->renderer.pdfDocument = nil;
        }
      };

  [controller presentAnimated:YES completionHandler:completionHandler];
}

- (void)writePdf:(nonnull FlutterStandardTypedData*)data {
  CGDataProviderRef dataProvider = CGDataProviderCreateWithData(
      NULL, data.data.bytes, data.data.length, NULL);
  if (renderer.pdfDocument != nil) {
    CGPDFDocumentRelease(renderer.pdfDocument);
    renderer.pdfDocument = nil;
  }
  renderer.pdfDocument = CGPDFDocumentCreateWithProvider(dataProvider);
  CGDataProviderRelease(dataProvider);
  [renderer.lock unlock];
}

- (void)sharePdf:(nonnull FlutterStandardTypedData*)data
    withSourceRect:(CGRect)rect {
  NSURL* tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()
                                isDirectory:YES];

  CFUUIDRef uuid = CFUUIDCreate(NULL);
  assert(uuid != NULL);

  CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
  assert(uuidStr != NULL);

  NSURL* fileURL = [[tmpDirURL
      URLByAppendingPathComponent:[NSString
                                      stringWithFormat:@"pdf-%@", uuidStr]]
      URLByAppendingPathExtension:@"pdf"];
  assert(fileURL != NULL);

  CFRelease(uuidStr);
  CFRelease(uuid);

  NSString* path = [fileURL path];

  NSError* error;
  if (![[data data] writeToFile:path
                        options:NSDataWritingAtomic
                          error:&error]) {
    NSLog(@"sharePdf error: %@", [error localizedDescription]);
    return;
  }

  UIActivityViewController* activityViewController =
      [[UIActivityViewController alloc] initWithActivityItems:@[ fileURL ]
                                        applicationActivities:nil];
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    UIViewController* controller =
        [UIApplication sharedApplication].keyWindow.rootViewController;
    activityViewController.popoverPresentationController.sourceView =
        controller.view;
    activityViewController.popoverPresentationController.sourceRect = rect;
  }
  [[UIApplication sharedApplication].keyWindow.rootViewController
      presentViewController:activityViewController
                   animated:YES
                 completion:nil];
}

@end
