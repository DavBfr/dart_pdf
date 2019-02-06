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

#import "PageRenderer.h"

@implementation PdfPrintPageRenderer {
  FlutterMethodChannel* channel;
  CGPDFDocumentRef pdfDocument;
  NSLock* lock;
}

- (instancetype)init:(FlutterMethodChannel*)channel {
  self = [super init];
  self->channel = channel;
  self->lock = [[NSLock alloc] init];
  self->pdfDocument = nil;
  return self;
}

- (void)dealloc {
  if (self->pdfDocument != nil) {
    CGPDFDocumentRelease(self->pdfDocument);
  }
}

- (NSInteger)numberOfPages {
  NSNumber* width = [[NSNumber alloc] initWithDouble:self.paperRect.size.width];
  NSNumber* height =
      [[NSNumber alloc] initWithDouble:self.paperRect.size.height];
  NSNumber* marginLeft =
      [[NSNumber alloc] initWithDouble:self.printableRect.origin.x];
  NSNumber* marginTop =
      [[NSNumber alloc] initWithDouble:self.printableRect.origin.y];
  NSNumber* marginRight =
      [[NSNumber alloc] initWithDouble:self.paperRect.size.width -
                                       (self.printableRect.origin.x +
                                        self.printableRect.size.width)];
  NSNumber* marginBottom =
      [[NSNumber alloc] initWithDouble:self.paperRect.size.height -
                                       (self.printableRect.origin.y +
                                        self.printableRect.size.height)];

  NSDictionary* arg = @{
    @"width" : width,
    @"height" : height,
    @"marginLeft" : marginLeft,
    @"marginTop" : marginTop,
    @"marginRight" : marginRight,
    @"marginBottom" : marginBottom,
  };

  [lock lock];
  [channel invokeMethod:@"onLayout" arguments:arg];
  [lock lock];
  [lock unlock];

  size_t pages = CGPDFDocumentGetNumberOfPages(pdfDocument);

  return pages;
}

- (void)drawPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)printableRect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGPDFPageRef page = CGPDFDocumentGetPage(pdfDocument, pageIndex + 1);
  CGContextScaleCTM(ctx, 1.0, -1.0);
  CGContextTranslateCTM(ctx, 0.0, -self.paperRect.size.height);
  CGContextDrawPDFPage(ctx, page);
}

void dataProviderReleaseDataCallback(void* info,
                                     const void* data,
                                     size_t size) {
  free((void*)data);
}

- (void)setDocument:(NSData*)data {
  void* buffer = malloc(data.length);
  memcpy(buffer, data.bytes, data.length);
  CGDataProviderRef dataProvider = CGDataProviderCreateWithData(
      NULL, buffer, data.length, dataProviderReleaseDataCallback);
  if (pdfDocument != nil) {
    CGPDFDocumentRelease(pdfDocument);
    pdfDocument = nil;
  }
  pdfDocument = CGPDFDocumentCreateWithProvider(dataProvider);
  CGDataProviderRelease(dataProvider);
  [lock unlock];
}

@end
