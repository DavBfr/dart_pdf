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

    public init(printing: PrintingPlugin, index: Int) {
        self.printing = printing
        self.index = index
        super.init(frame: NSZeroRect)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Return the number of pages available for printing
    override public func knowsPageRange(_ range: NSRangePointer) -> Bool {
        setFrameSize(printOperation!.printPanel.printInfo.paperSize)
        setBoundsSize(printOperation!.printPanel.printInfo.paperSize)
        range.pointee.length = pdfDocument?.numberOfPages ?? 0
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

        let window = NSApplication.shared.mainWindow!
        printOperation!.runModal(for: window, delegate: self, didRun: #selector(printOperationDidRun(printOperation:success:contextInfo:)), contextInfo: nil)
    }

    override public func draw(_: NSRect) {
        if pdfDocument != nil {
            let ctx = NSGraphicsContext.current?.cgContext
            if page != nil {
                ctx?.drawPDFPage(page!)
            }
        }
    }

    public func directPrintPdf(name _: String, data _: Data, withPrinter _: String) {}

    public func printPdf(name: String, withPageSize _: CGSize, andMargin _: CGRect) {
        let sharedInfo = NSPrintInfo.shared
        let sharedDict = sharedInfo.dictionary()
        let printInfoDict = NSMutableDictionary(dictionary: sharedDict)
        let printInfo = NSPrintInfo(dictionary: printInfoDict as! [NSPrintInfo.AttributeKey: Any])

        // Print the custom view
        printOperation = NSPrintOperation(view: self, printInfo: printInfo)
        printOperation!.jobTitle = name
        printOperation!.printPanel.options = [.showsPreview]

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
        printing.onCompleted(printJob: self, completed: false, error: error as NSString?)
    }

    public static func sharePdf(data: Data, withSourceRect rect: CGRect, andName name: String) {
        let tempFile = NSTemporaryDirectory() + name
        let file = NSURL(fileURLWithPath: tempFile)

        do {
            try data.write(to: file.absoluteURL!)
        } catch {
            print("Unable to save the pdf file to \(tempFile)")
            return
        }

        let view = NSApplication.shared.mainWindow!.contentView!
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

        let webView = WebView()
        webView.mainFrame.loadHTMLString(data, baseURL: baseUrl)
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

    public static func pickPrinter(result: @escaping FlutterResult, withSourceRect _: CGRect) {
        result(NSNumber(value: 1))
    }

    public func rasterPdf(data: Data, pages: [Int]?, scale: CGFloat) {
        let provider = CGDataProvider(data: data as CFData)!
        let document = CGPDFDocument(provider)!

        DispatchQueue.global().async {
            let pageCount = document.numberOfPages

            for pageNum in pages ?? Array(0 ... pageCount - 1) {
                guard let page = document.page(at: pageNum + 1) else { continue }
                let rect = page.getBoxRect(.mediaBox)
                let width = Int(rect.width * scale)
                let height = Int(rect.height * scale)
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
                        context!.scaleBy(x: scale, y: scale)
                        context!.drawPDFPage(page)
                    }
                }

                DispatchQueue.main.sync {
                    self.printing.onPageRasterized(printJob: self, imageData: data, width: width, height: height)
                }
            }

            DispatchQueue.main.sync {
                self.printing.onPageRasterEnd(printJob: self)
            }
        }
    }

    public static func printingInfo() -> NSDictionary {
        let data: NSDictionary = [
            "directPrint": false,
            "dynamicLayout": false,
            "canPrint": true,
            "canConvertHtml": true,
            "canShare": true,
            "canRaster": true,
        ]
        return data
    }
}
