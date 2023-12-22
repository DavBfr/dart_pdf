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

import FlutterMacOS
import Foundation
import WebKit

func dataProviderReleaseDataCallback(info _: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size _: Int) {
    data.deallocate()
}

public class PrintJob: NSView, NSSharingServicePickerDelegate {
    private var printing: PrintingPlugin
    public var index: Int

    private var printOperation: NSPrintOperation?
    private var pdfDocument: CGPDFDocument?
    private var page: CGPDFPage?
    private let semaphore = DispatchSemaphore(value: 0)
    private var dynamic = false
    private var _window: NSWindow?

    public init(printing: PrintingPlugin, index: Int) {
        self.printing = printing
        self.index = index
        super.init(frame: NSZeroRect)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Return the number of pages available for printing
    override public func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let size = printOperation!.showsPrintPanel ? printOperation!.printPanel.printInfo.paperSize : printOperation!.printInfo.paperSize

        setFrameSize(size)
        setBoundsSize(size)

        if dynamic {
            printing.onLayout(
                printJob: self,
                width: printOperation!.printInfo.paperSize.width,
                height: printOperation!.printInfo.paperSize.height,
                marginLeft: printOperation!.printInfo.leftMargin,
                marginTop: printOperation!.printInfo.topMargin,
                marginRight: printOperation!.printInfo.rightMargin,
                marginBottom: printOperation!.printInfo.bottomMargin
            )

            // Block the main thread, waiting for a document
            semaphore.wait()
        }

        if pdfDocument != nil {
            range.pointee.length = pdfDocument!.numberOfPages
            let page = pdfDocument!.page(at: 1)
            let size = page?.getBoxRect(CGPDFBox.mediaBox) ?? NSZeroRect
            setFrameSize(size.size)
            setBoundsSize(size.size)
        } else {
            range.pointee.length = 0
        }
        return true
    }

    // Return the drawing rectangle for a particular page number
    override public func rectForPage(_ page: Int) -> NSRect {
        self.page = pdfDocument?.page(at: page)
        return self.page?.getBoxRect(CGPDFBox.mediaBox) ?? NSZeroRect
    }

    @objc func printOperationDidRun(printOperation _: NSPrintOperation, success: Bool, contextInfo _: UnsafeRawPointer?) {
        printing.onCompleted(printJob: self, completed: success, error: nil)
    }

    func setDocument(_ data: Data?) {
        let bytesPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data?.count ?? 0)
        data?.copyBytes(to: bytesPointer, count: data?.count ?? 0)
        let dataProvider = CGDataProvider(dataInfo: nil, data: bytesPointer, size: data?.count ?? 0, releaseData: dataProviderReleaseDataCallback)
        pdfDocument = CGPDFDocument(dataProvider!)

        if dynamic {
            // Unblock the main thread
            semaphore.signal()
            return
        }

        DispatchQueue.main.async {
            self.printOperation!.runModal(for: self._window!, delegate: self, didRun: #selector(self.printOperationDidRun(printOperation:success:contextInfo:)), contextInfo: nil)
        }
    }

    override public func draw(_: NSRect) {
        if pdfDocument != nil {
            let ctx = NSGraphicsContext.current?.cgContext
            if page != nil {
                ctx?.drawPDFPage(page!)
            }
        }
    }

    public func listPrinters() -> [NSDictionary] {
        var printers: Array = [NSDictionary]()

        for name in NSPrinter.printerNames {
            let printer = NSPrinter(name: name)
            if printer == nil {
                continue
            }
            let pr: NSDictionary = [
                "url": name,
                "name": name,
                "model": printer!.type,
            ]
            printers.append(pr)
        }

        return printers
    }

    public func printPdf(name: String, withPageSize size: CGSize, andMargin _: CGRect, withPrinter printer: String?, dynamically dyn: Bool, andWindow window: NSWindow) {
        dynamic = dyn
        _window = window
        let sharedInfo = NSPrintInfo.shared
        let sharedDict = sharedInfo.dictionary()
        let printInfoDict = NSMutableDictionary(dictionary: sharedDict)
        let printInfo = NSPrintInfo(dictionary: printInfoDict as! [NSPrintInfo.AttributeKey: Any])

        printInfo.paperSize = size
        if size.width > size.height {
            printInfo.orientation = NSPrintInfo.PaperOrientation.landscape
        }

        // A printer is specified
        if printer != nil {
            let pr = NSPrinter(name: printer!)
            if pr == nil {
                printing.onCompleted(printJob: self, completed: false, error: "Unable to find the printer")
                return
            }
            printInfo.printer = pr!
        }

        // The custom print view
        printOperation = NSPrintOperation(view: self, printInfo: printInfo)
        printOperation!.jobTitle = name
        printOperation!.printPanel.options = [.showsPreview, .showsCopies]
        if printer != nil {
            printOperation!.showsPrintPanel = false
            printOperation!.showsProgressPanel = false
        }

        if dynamic {
            printOperation!.printPanel.options = [.showsPreview, .showsPaperSize, .showsOrientation, .showsCopies]
            printOperation!.runModal(for: _window!, delegate: self, didRun: #selector(printOperationDidRun(printOperation:success:contextInfo:)), contextInfo: nil)
            return
        }

        printing.onLayout(
            printJob: self,
            width: printOperation!.printInfo.paperSize.width,
            height: printOperation!.printInfo.paperSize.height,
            marginLeft: printOperation!.printInfo.leftMargin,
            marginTop: printOperation!.printInfo.topMargin,
            marginRight: printOperation!.printInfo.rightMargin,
            marginBottom: printOperation!.printInfo.bottomMargin
        )
    }

    func cancelJob(_ error: String?) {
        pdfDocument = nil
        if dynamic {
            semaphore.signal()
        } else {
            printing.onCompleted(printJob: self, completed: false, error: error as NSString?)
        }
    }

    public static func sharePdf(data: Data, withSourceRect rect: CGRect, andName name: String, andWindow view: NSView) {
        let tempFile = NSTemporaryDirectory() + name
        let file = NSURL(fileURLWithPath: tempFile)

        do {
            try data.write(to: file.absoluteURL!)
        } catch {
            print("Unable to save the pdf file to \(tempFile)")
            return
        }

        let sharingServicePicker = NSSharingServicePicker(items: [file])
        sharingServicePicker.show(relativeTo: rect, of: view, preferredEdge: NSRectEdge.maxY)

//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
//            let fileManager = FileManager.default
//            do {
//                try fileManager.removeItem(atPath: tempFile)
//            } catch let error as NSError {
//                print("Unable to delete \(tempFile): \(error)")
//            }
//        }
    }

    public func convertHtml(_ data: String, withPageSize size: CGRect, andMargin margin: CGRect, andBaseUrl baseUrl: URL?) {
        let tempFile = NSTemporaryDirectory() + NSUUID().uuidString
        let directoryURL = URL(fileURLWithPath: tempFile)

        let printOpts: [NSPrintInfo.AttributeKey: Any] = [NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save, NSPrintInfo.AttributeKey.jobSavingURL: directoryURL]
        let printInfo = NSPrintInfo(dictionary: printOpts)
        printInfo.horizontalPagination = NSPrintInfo.PaginationMode.automatic
        printInfo.verticalPagination = NSPrintInfo.PaginationMode.automatic
        printInfo.paperSize.width = size.width
        printInfo.paperSize.height = size.height
        printInfo.topMargin = margin.minY
        printInfo.leftMargin = margin.minX
        printInfo.rightMargin = size.width - margin.maxX
        printInfo.bottomMargin = size.height - margin.maxY

        let webView = WKWebView(frame: viewController!.view.bounds)
        webView.loadHTMLString(data, baseURL: baseUrl ?? Bundle.main.bundleURL)
        let when = DispatchTime.now() + 1

        DispatchQueue.main.asyncAfter(deadline: when) {
            let printOperation = NSPrintOperation(view: webView.mainFrame.frameView.documentView, printInfo: printInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false
            printOperation.run()

            do {
                let data = try Data(contentsOf: directoryURL)
                self.printing.onHtmlRendered(printJob: self, pdfData: data)
                let fileManager = FileManager.default
                try fileManager.removeItem(atPath: tempFile)
            } catch {
                self.printing.onHtmlError(printJob: self, error: "Unable to load the pdf file from \(tempFile)")
            }
        }
    }

    public func rasterPdf(data: Data, pages: [Int]?, scale: CGFloat) {
        guard
            let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider)
        else {
            printing.onPageRasterEnd(printJob: self, error: "Cannot raster a malformed PDF file")
            return
        }

        DispatchQueue.global().async {
            let pageCount = document.numberOfPages

            for pageNum in pages ?? Array(0 ... pageCount - 1) {
                guard let page = document.page(at: pageNum + 1) else { continue }
                let angle = CGFloat(page.rotationAngle) * CGFloat.pi / -180
                let rect = page.getBoxRect(.mediaBox)
                let width = Int(abs((cos(angle) * rect.width + sin(angle) * rect.height) * scale))
                let height = Int(abs((cos(angle) * rect.height + sin(angle) * rect.width) * scale))
                let stride = width * 4
                var data = Data(repeating: 0, count: stride * height)

                data.withUnsafeMutableBytes { (outputBytes: UnsafeMutableRawBufferPointer) in
                    let rgb = CGColorSpaceCreateDeviceRGB()
                    let context = CGContext(
                        data: outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: stride,
                        space: rgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    )

                    if context != nil {
                        context!.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
                        context!.scaleBy(x: scale, y: scale)
                        context!.rotate(by: angle)
                        context!.translateBy(x: -rect.width / 2, y: -rect.height / 2)
                        context!.drawPDFPage(page)
                    }
                }

                DispatchQueue.main.sync {
                    self.printing.onPageRasterized(printJob: self, imageData: data, width: width, height: height)
                }
            }

            DispatchQueue.main.sync {
                self.printing.onPageRasterEnd(printJob: self, error: nil)
            }
        }
    }

    public static func printingInfo() -> NSDictionary {
        let data: NSDictionary = [
            "directPrint": true,
            "dynamicLayout": true,
            "canPrint": true,
            "canConvertHtml": true,
            "canShare": true,
            "canRaster": true,
            "canListPrinters": true,
        ]
        return data
    }
}
