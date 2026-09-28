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
import PDFKit
import WebKit

public class PrintJob: NSView, NSSharingServicePickerDelegate {
    private var printing: PrintingPlugin
    public var index: Int

    private var printOperation: NSPrintOperation?
    // PDFKit rather than CGPDFDocument: see PdfPageRenderer. The document has
    // to outlive every page it hands out, because PDFPage does not retain it.
    private var pdfDocument: PDFDocument?
    private var page: PDFPage?
    // The HTML conversion owns these for the length of one convertHtml call.
    private var htmlWebView: WKWebView?
    private var htmlDelegate: NSObject?
    private var htmlBackstop: DispatchWorkItem?
    private var htmlPrintInfo: NSPrintInfo?
    private var htmlTempFile: String?
    private var htmlWindow: NSWindow?
    private var htmlStarted = false
    private var htmlFinished = false
    private var isWaitingForDocument = false
    private var documentReceived = false
    private var dynamic = false
    private var _window: NSWindow?
    private var lastLayoutParams: (width: CGFloat, height: CGFloat, marginLeft: CGFloat, marginTop: CGFloat, marginRight: CGFloat, marginBottom: CGFloat)?

    public init(printing: PrintingPlugin, index: Int) {
        self.printing = printing
        self.index = index
        super.init(frame: NSZeroRect)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func layoutParamsChanged(_ new: (width: CGFloat, height: CGFloat, marginLeft: CGFloat, marginTop: CGFloat, marginRight: CGFloat, marginBottom: CGFloat)) -> Bool {
        guard let last = lastLayoutParams else { return true }
        return last.width != new.width || last.height != new.height ||
            last.marginLeft != new.marginLeft || last.marginTop != new.marginTop ||
            last.marginRight != new.marginRight || last.marginBottom != new.marginBottom
    }

    /// Return the number of pages available for printing
    override public func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let size = printOperation!.showsPrintPanel ? printOperation!.printPanel.printInfo.paperSize : printOperation!.printInfo.paperSize

        setFrameSize(size)
        setBoundsSize(size)

        if dynamic {
            let currentParams = (
                width: printOperation!.printInfo.paperSize.width,
                height: printOperation!.printInfo.paperSize.height,
                marginLeft: printOperation!.printInfo.leftMargin,
                marginTop: printOperation!.printInfo.topMargin,
                marginRight: printOperation!.printInfo.rightMargin,
                marginBottom: printOperation!.printInfo.bottomMargin
            )

            if layoutParamsChanged(currentParams) {
                lastLayoutParams = currentParams

                printing.onLayout(
                    printJob: self,
                    width: currentParams.width,
                    height: currentParams.height,
                    marginLeft: currentParams.marginLeft,
                    marginTop: currentParams.marginTop,
                    marginRight: currentParams.marginRight,
                    marginBottom: currentParams.marginBottom
                )

                // Wait for document using RunLoop to keep main thread responsive
                isWaitingForDocument = true
                documentReceived = false
                let runLoop = RunLoop.current
                let timeout = Date(timeIntervalSinceNow: 30.0)
                while !documentReceived && Date() < timeout {
                    runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
                }
                isWaitingForDocument = false
            }
        }

        if let document = pdfDocument {
            range.pointee.length = document.pageCount
            // The crop box is what is meant to be seen, and its origin is not
            // necessarily zero.
            let size = document.page(at: 0).map { PdfPageRenderer.size(of: $0) } ?? .zero
            setFrameSize(size)
            setBoundsSize(size)
        } else {
            range.pointee.length = 0
        }
        return true
    }

    /// Return the drawing rectangle for a particular page number
    override public func rectForPage(_ page: Int) -> NSRect {
        // NSPrintOperation numbers pages from 1, PDFKit from 0.
        self.page = pdfDocument?.page(at: page - 1)
        guard let current = self.page else {
            return NSZeroRect
        }
        return NSRect(origin: .zero, size: PdfPageRenderer.size(of: current))
    }

    @objc func printOperationDidRun(printOperation _: NSPrintOperation, success: Bool, contextInfo _: UnsafeRawPointer?) {
        printing.onCompleted(printJob: self, completed: success, error: nil)
    }

    func setDocument(_ data: Data?) {
        // An empty or malformed document must not crash: PDFDocument returns
        // nil for both.
        if let data, !data.isEmpty {
            pdfDocument = PDFDocument(data: data)
        } else {
            pdfDocument = nil
        }

        if dynamic {
            // Signal that document is ready
            documentReceived = true
            return
        }

        if pdfDocument == nil {
            printing.onCompleted(printJob: self, completed: false, error: "Unable to load the PDF document")
            return
        }

        DispatchQueue.main.async {
            self.printOperation!.runModal(for: self._window!, delegate: self, didRun: #selector(self.printOperationDidRun(printOperation:success:contextInfo:)), contextInfo: nil)
        }
    }

    override public func draw(_: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              // Held so the document cannot be released while the page draws.
              pdfDocument != nil,
              let page = page
        else {
            return
        }

        PdfPageRenderer.draw(page: page, in: ctx, to: bounds)
    }

    public func listPrinters() -> [NSDictionary] {
        var printers: Array = [NSDictionary]()

        // NSPrinter answers the name and the model, but not whether a queue is
        // the default or whether it will print, so the contract's 'default',
        // 'available' and 'location' keys were simply absent and Dart turned
        // them into false, true and null. PrintCore has them.
        let details = PrintJob.printerDetails()

        for name in NSPrinter.printerNames {
            let printer = NSPrinter(name: name)
            if printer == nil {
                continue
            }

            let pr: NSMutableDictionary = [
                "url": name,
                "name": name,
                "model": printer!.type,
            ]

            if let detail = details[name] {
                pr["default"] = detail.isDefault
                pr["available"] = detail.isAvailable
                if let location = detail.location {
                    pr["location"] = location
                }
            }

            printers.append(pr)
        }

        return printers
    }

    private struct PrinterDetail {
        let isDefault: Bool
        let isAvailable: Bool
        let location: String?
    }

    /// What PrintCore knows about each queue, by name.
    ///
    /// Returns an empty map when the print server cannot be reached, so
    /// listPrinters degrades to the three keys it used to answer rather than
    /// failing.
    private static func printerDetails() -> [String: PrinterDetail] {
        var list: Unmanaged<CFArray>?
        guard PMServerCreatePrinterList(nil, &list) == noErr, let list else {
            return [:]
        }

        // takeRetainedValue owns the array, so it is released when this
        // function returns, on every path.
        let cfPrinters = list.takeRetainedValue()
        var details: [String: PrinterDetail] = [:]

        for index in 0 ..< CFArrayGetCount(cfPrinters) {
            // PMPrinter is an OpaquePointer, not a class, so the array cannot
            // be bridged to a Swift array: doing that crashes.
            guard let raw = CFArrayGetValueAtIndex(cfPrinters, index) else {
                continue
            }
            let printer = PMPrinter(raw)

            guard let name = PMPrinterGetName(printer) as String? else {
                continue
            }

            var state = PMPrinterState(kPMPrinterIdle)
            let hasState = PMPrinterGetState(printer, &state) == noErr
            let location = PMPrinterGetLocation(printer) as String?

            details[name] = PrinterDetail(
                isDefault: PMPrinterIsDefault(printer),
                // A stopped queue holds everything sent to it, so it is not
                // available; an unreadable state is assumed printable, as
                // before.
                isAvailable: !hasState || state != PMPrinterState(kPMPrinterStopped),
                // An empty location is no location, and must not become "".
                location: location?.isEmpty == false ? location : nil
            )
        }

        return details
    }

    public func printPdf(name: String, withPageSize rawSize: CGSize, andMargin _: CGRect, withPrinter printer: String?, dynamically dyn: Bool, andWindow window: NSWindow) {
        // A roll format leaves an axis unspecified, which arrives as 0 (or, on
        // an older Dart side, as infinity). NSPrintInfo cannot use either.
        let size = PrintJob.usableSize(rawSize)
        dynamic = dyn
        _window = window
        lastLayoutParams = nil
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
        lastLayoutParams = nil
        if dynamic {
            documentReceived = true
        } else {
            printing.onCompleted(printJob: self, completed: false, error: error as NSString?)
        }
    }

    /// Keeps the sharing-picker delegates alive until the picker is done with
    /// them: NSSharingServicePicker holds its delegate weakly.
    private static var sharingPickerDelegates: [SharingPickerCleanup] = []

    /// Offer the document through the sharing picker.
    ///
    /// Returns false when the file could not be written, instead of letting
    /// the caller believe every share succeeded.
    public static func sharePdf(data: Data, withSourceRect rect: CGRect, andName name: String, andWindow view: NSView) -> Bool {
        // Defensive basename: NSTemporaryDirectory() + name used to accept a
        // path, which pointed outside the temp directory.
        var safeName = (name as NSString).lastPathComponent
        if safeName.isEmpty || safeName == "." || safeName == ".." {
            safeName = "document.pdf"
        }

        let tempFile = NSTemporaryDirectory() + safeName
        let file = NSURL(fileURLWithPath: tempFile)

        guard let fileURL = file.absoluteURL else {
            return false
        }

        do {
            try data.write(to: fileURL)
        } catch {
            print("Unable to save the pdf file to \(tempFile)")
            return false
        }

        let sharingServicePicker = NSSharingServicePicker(items: [file])
        let delegate = SharingPickerCleanup(path: tempFile)
        sharingServicePicker.delegate = delegate
        // Kept alive until the picker is done with it.
        PrintJob.sharingPickerDelegates.append(delegate)
        sharingServicePicker.show(relativeTo: rect, of: view, preferredEdge: NSRectEdge.maxY)
        return true
    }

    /// Removes the shared temp file once the service has finished with it.
    ///
    /// The cleanup used to be commented out, so every share left a copy of the
    /// document in the temp directory.
    private class SharingPickerCleanup: NSObject, NSSharingServicePickerDelegate {
        init(path: String) {
            self.path = path
        }

        let path: String

        func sharingServicePicker(_: NSSharingServicePicker, didChoose service: NSSharingService?) {
            if service == nil {
                // Dismissed without choosing: nothing will read the file.
                remove()
                return
            }
            // A service may still be reading the file, so give it a moment
            // before taking the copy away.
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
                self?.remove()
            }
        }

        private func remove() {
            try? FileManager.default.removeItem(atPath: path)
            PrintJob.sharingPickerDelegates.removeAll { $0 === self }
        }
    }

    /// How long to wait for a page that never finishes loading.
    ///
    /// This replaces a fixed one-second wait, which snapshotted whatever
    /// WebKit happened to have laid out and reported it as a success.
    private static let htmlLoadBackstop = 30.0

    @available(macOS 11.0, *)
    public func convertHtml(_ data: String, withPageSize size: CGRect, andMargin margin: CGRect, andBaseUrl baseUrl: URL?, andWindow window: NSWindow?) {
        let tempFile = NSTemporaryDirectory() + NSUUID().uuidString + ".pdf"

        let printOpts: [NSPrintInfo.AttributeKey: Any] = [
            NSPrintInfo.AttributeKey.jobDisposition: NSPrintInfo.JobDisposition.save,
            NSPrintInfo.AttributeKey.jobSavingURL: URL(fileURLWithPath: tempFile),
        ]
        let printInfo = NSPrintInfo(dictionary: printOpts)
        printInfo.horizontalPagination = NSPrintInfo.PaginationMode.automatic
        printInfo.verticalPagination = NSPrintInfo.PaginationMode.automatic
        // paperSize is a value, so the two assignments this replaces wrote to a
        // temporary. It made no difference, because the print operation the
        // rest of this setup describes was never created: the conversion
        // snapshotted a zero-sized web view instead, which WebKit laid out at
        // its intrinsic minimum width and captured as one very long page.
        printInfo.paperSize = NSSize(width: size.width, height: size.height)
        printInfo.topMargin = margin.minY
        printInfo.leftMargin = margin.minX
        printInfo.rightMargin = size.width - margin.maxX
        printInfo.bottomMargin = size.height - margin.maxY
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        htmlPrintInfo = printInfo
        htmlTempFile = tempFile
        htmlWindow = window
        htmlStarted = false
        htmlFinished = false

        // Sized to the printable area, so WebKit breaks lines where the paper
        // does.
        let contentWidth = max(size.width - printInfo.leftMargin - printInfo.rightMargin, 1)
        let contentHeight = max(size.height - printInfo.topMargin - printInfo.bottomMargin, 1)
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        let delegate = HtmlNavigationDelegate(job: self)
        webView.navigationDelegate = delegate
        htmlWebView = webView
        htmlDelegate = delegate

        // Rendering is driven by the navigation delegate; this only stops a
        // page that never loads from hanging the Dart future for ever.
        let backstop = DispatchWorkItem { [weak self] in
            self?.renderHtml()
        }
        htmlBackstop = backstop
        DispatchQueue.main.asyncAfter(deadline: .now() + PrintJob.htmlLoadBackstop, execute: backstop)

        webView.loadHTMLString(data, baseURL: baseUrl)
    }

    /// Drives the HTML conversion from the navigation rather than from a timer.
    private class HtmlNavigationDelegate: NSObject, WKNavigationDelegate {
        init(job: PrintJob) {
            self.job = job
        }

        private weak var job: PrintJob?

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            if #available(macOS 11.0, *) {
                job?.renderHtml()
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            job?.failHtml("Unable to load the HTML document: \(error.localizedDescription)")
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            job?.failHtml("Unable to load the HTML document: \(error.localizedDescription)")
        }
    }

    /// Print the loaded page to a PDF at the requested paper size.
    @available(macOS 11.0, *)
    fileprivate func renderHtml() {
        if htmlStarted || htmlFinished {
            return
        }
        htmlStarted = true
        htmlBackstop?.cancel()

        guard let webView = htmlWebView, let printInfo = htmlPrintInfo else {
            failHtml("The HTML conversion has no document to render")
            return
        }

        guard let window = htmlWindow else {
            // With no window there is nothing to run a print operation in, so
            // fall back to the page capture. It ignores the paper size, but it
            // is better than an error.
            webView.createPDF { [weak self] result in
                switch result {
                case let .success(data):
                    self?.finishHtml(data)
                case let .failure(error):
                    self?.failHtml("Unable to create PDF: \(error.localizedDescription)")
                }
            }
            return
        }

        webView.frame = NSRect(origin: .zero, size: printInfo.paperSize)

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = NSRect(origin: .zero, size: printInfo.paperSize)
        operation.runModal(
            for: window,
            delegate: self,
            didRun: #selector(htmlOperationDidRun(printOperation:success:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc func htmlOperationDidRun(printOperation _: NSPrintOperation, success: Bool, contextInfo _: UnsafeRawPointer?) {
        guard success else {
            failHtml("Unable to render the HTML document")
            return
        }

        guard let tempFile = htmlTempFile,
              let data = FileManager.default.contents(atPath: tempFile),
              !data.isEmpty
        else {
            failHtml("The rendered HTML document could not be read")
            return
        }

        finishHtml(data)
    }

    private func finishHtml(_ data: Data) {
        if htmlFinished {
            return
        }
        htmlFinished = true
        releaseHtml()
        printing.onHtmlRendered(printJob: self, pdfData: data)
    }

    fileprivate func failHtml(_ error: String) {
        if htmlFinished {
            return
        }
        htmlFinished = true
        releaseHtml()
        printing.onHtmlError(printJob: self, error: error)
    }

    /// Release everything one conversion owns, including its temp file.
    private func releaseHtml() {
        htmlBackstop?.cancel()
        htmlBackstop = nil
        htmlWebView?.navigationDelegate = nil
        htmlWebView = nil
        htmlDelegate = nil
        htmlPrintInfo = nil
        htmlWindow = nil

        if let tempFile = htmlTempFile {
            try? FileManager.default.removeItem(atPath: tempFile)
            htmlTempFile = nil
        }
    }

    public func rasterPdf(data: Data, pages: [Int]?, scale: CGFloat, background: UInt32 = 0xFFFF_FFFF) {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            printing.onPageRasterEnd(printJob: self, error: "Cannot raster a malformed PDF file")
            return
        }

        DispatchQueue.global().async {
            // document is captured, so it outlives every page below.
            for pageNum in pages ?? Array(0 ... document.pageCount - 1) {
                guard let page = document.page(at: pageNum),
                      let raster = PdfPageRenderer.raster(
                          page: page,
                          scale: scale,
                          background: background
                      )
                else {
                    continue
                }

                DispatchQueue.main.sync {
                    self.printing.onPageRasterized(printJob: self, imageData: raster.data, width: raster.width, height: raster.height)
                }
            }

            DispatchQueue.main.sync {
                self.printing.onPageRasterEnd(printJob: self, error: nil)
            }
        }
    }

    public static func printingInfo() -> NSDictionary {
        var html = false
        if #available(macOS 11.0, *) {
            html = true
        }
        return [
            "directPrint": true,
            "dynamicLayout": true,
            "canPrint": true,
            "canConvertHtml": html,
            "canShare": true,
            "canRaster": true,
            "canListPrinters": true,
        ]
    }

    /// Replace an unspecified or non-finite axis with A4's, in points.
    static func usableSize(_ size: CGSize) -> CGSize {
        let fallback = CGSize(width: 595.28, height: 841.89)
        let width = size.width.isFinite && size.width > 0 ? size.width : fallback.width
        let height = size.height.isFinite && size.height > 0 ? size.height : fallback.height
        return CGSize(width: width, height: height)
    }
}
