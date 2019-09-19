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

import Flutter

func dataProviderReleaseDataCallback(info _: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size _: Int) {
    data.deallocate()
}

class PdfPrintPageRenderer: UIPrintPageRenderer {
    private var channel: FlutterMethodChannel?
    private var pdfDocument: CGPDFDocument?
    private var lock: NSLock?

    init(_ channel: FlutterMethodChannel?) {
        super.init()
        self.channel = channel
        lock = NSLock()
        pdfDocument = nil
    }

    override func drawPage(at pageIndex: Int, in _: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        let page = pdfDocument?.page(at: pageIndex + 1)
        ctx?.scaleBy(x: 1.0, y: -1.0)
        ctx?.translateBy(x: 0.0, y: -paperRect.size.height)
        ctx?.drawPDFPage(page!)
    }

    func cancelJob() {
        pdfDocument = nil
        lock?.unlock()
    }

    func setDocument(_ data: Data?) {
        let bytesPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data?.count ?? 0)
        data?.copyBytes(to: bytesPointer, count: data?.count ?? 0)
        let dataProvider = CGDataProvider(dataInfo: nil, data: bytesPointer, size: data?.count ?? 0, releaseData: dataProviderReleaseDataCallback)
        pdfDocument = CGPDFDocument(dataProvider!)
        lock?.unlock()
    }

    override var numberOfPages: Int {
        let width = NSNumber(value: Double(paperRect.size.width))
        let height = NSNumber(value: Double(paperRect.size.height))
        let marginLeft = NSNumber(value: Double(printableRect.origin.x))
        let marginTop = NSNumber(value: Double(printableRect.origin.y))
        let marginRight = NSNumber(value: Double(paperRect.size.width - (printableRect.origin.x + printableRect.size.width)))
        let marginBottom = NSNumber(value: Double(paperRect.size.height - (printableRect.origin.y + printableRect.size.height)))

        let arg = [
            "width": width,
            "height": height,
            "marginLeft": marginLeft,
            "marginTop": marginTop,
            "marginRight": marginRight,
            "marginBottom": marginBottom,
        ]

        lock?.lock()
        channel?.invokeMethod("onLayout", arguments: arg)
        lock?.lock()
        lock?.unlock()

        let pages = pdfDocument?.numberOfPages ?? 0

        return pages
    }
}
