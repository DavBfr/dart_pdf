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
import PDFKit
import WebKit

/// A variable that holds the selected printers to prevent recreate it if selected again
/// Each printer will be identified by its URL string
var selectedPrinters = [String: UIPrinter]()

/// Holds the printer after it was picked
var pickedPrinter: UIPrinter?

public class PrintJob: UIPrintPageRenderer, UIPrintInteractionControllerDelegate {
    private var printing: PrintingPlugin
    public var index: Int
    private let pdfDocumentLock = NSLock()
    private var _pdfDocument: PDFDocument?
    /// UIKit queries numberOfPages from a background page-count thread
    /// (UIPrintPreviewViewController.updatePageCount) while setDocument and
    /// cancelJob replace the document on the main thread. An unsynchronized
    /// swap lets ARC free the old document mid-read. All access must go
    /// through this lock;
    /// the getter retains the document under the lock so callers always hold
    /// a strong reference to a live object.
    private var pdfDocument: PDFDocument? {
        get {
            pdfDocumentLock.lock()
            defer { pdfDocumentLock.unlock() }
            return _pdfDocument
        }
        set {
            pdfDocumentLock.lock()
            defer { pdfDocumentLock.unlock() }
            _pdfDocument = newValue
        }
    }

    private var urlObservation: NSKeyValueObservation?
    private var jobName: String?
    private var printerName: String?
    /// Built once in printPdf and re-assigned onto the shared controller
    /// immediately before every present() or print(to:).
    ///
    /// setDocument used to build a second one, which hard-coded .general and
    /// lost the requested orientation, so a landscape document printed to a
    /// portrait sheet on the static-layout path.
    private(set) var printInfo: UIPrintInfo?
    /// Whether the single result has already gone to Dart.
    private var completed = false
    private let semaphore = DispatchSemaphore(value: 0)
    private var dynamic = false
    private var currentSize: CGSize?
    private var forceCustomPrintPaper = false

    public init(printing: PrintingPlugin, index: Int) {
        self.printing = printing
        self.index = index
        super.init()
    }

    override public func drawPage(at pageIndex: Int, in _: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        // Hold a strong local reference so a concurrent setDocument can't
        // release the document (and the page it owns) while we draw.
        let document = pdfDocument
        guard let ctx, let page = document?.page(at: pageIndex) else {
            return
        }

        // UIKit's context has y increasing downwards; PDF drawing expects the
        // opposite.
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.translateBy(x: 0.0, y: -paperRect.size.height)
        PdfPageRenderer.draw(page: page, in: ctx, to: paperRect)
    }

    func cancelJob(_ error: String?) {
        pdfDocument = nil
        if dynamic {
            semaphore.signal()
        } else {
            reportCompleted(false, error)
        }
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
            // Unblock the thread waiting in numberOfPages
            semaphore.signal()
            return
        }

        if pdfDocument == nil {
            reportCompleted(false, "Unable to load the PDF document")
            return
        }

        DispatchQueue.main.async { [self] in
            startJob()
        }
    }

    override public var numberOfPages: Int {
        if dynamic {
            printing.onLayout(
                printJob: self,
                width: paperRect.size.width,
                height: paperRect.size.height,
                marginLeft: printableRect.origin.x,
                marginTop: printableRect.origin.y,
                marginRight: paperRect.size.width - (printableRect.origin.x + printableRect.size.width),
                marginBottom: paperRect.size.height - (printableRect.origin.y + printableRect.size.height)
            )

            // Block the main thread, waiting for a document
            semaphore.wait()
        }

        return pdfDocument?.pageCount ?? 0
    }

    func completionHandler(printController _: UIPrintInteractionController, completed: Bool, error: Error?) {
        if !completed, error != nil {
            print("Unable to print: \(error?.localizedDescription ?? "unknown error")")
        }

        reportCompleted(completed, error?.localizedDescription)
    }

    /// Report this job's single result to Dart.
    ///
    /// A job can fail on its way to UIKit and then have UIKit report as well,
    /// which the Dart side had to guard against.
    private func reportCompleted(_ success: Bool, _ error: String?) {
        if completed {
            return
        }
        completed = true
        printing.onCompleted(printJob: self, completed: success, error: error as NSString?)
    }

    public func printInteractionController(_: UIPrintInteractionController, choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
        if currentSize == nil {
            return paperList[0]
        }

        if forceCustomPrintPaper {
            return CustomPrintPaper(size: currentSize!)
        }

        for paper in paperList {
            if (paper.paperSize.width == currentSize!.width && paper.paperSize.height == currentSize!.height) ||
                (paper.paperSize.width == currentSize!.height && paper.paperSize.height == currentSize!.width)
            {
                return paper
            }
        }

        return UIPrintPaper.bestPaper(forPageSize: currentSize!, withPapersFrom: paperList)
    }

    func printPdf(name: String, withPageSize rawSize: CGSize, andMargin rawMargin: CGRect, withPrinter printerID: String?, dynamically dyn: Bool, outputType type: UIPrintInfo.OutputType, forceCustomPrintPaper: Bool = false) {
        // A roll format leaves an axis unspecified, which arrives as 0 (or,
        // from an older Dart side, as infinity). Either way an infinite size
        // makes the margin arithmetic below produce NaN, which ends up in the
        // document as a NaN MediaBox.
        let size = PrintJob.usableSize(rawSize)
        let margin = PrintJob.usableMargin(rawMargin, in: size)
        currentSize = size
        dynamic = dyn
        self.forceCustomPrintPaper = forceCustomPrintPaper

        let printing = UIPrintInteractionController.isPrintingAvailable
        if !printing {
            reportCompleted(false, "Printing not available")
            return
        }

        // Strip .pdf extension as UIPrintInteractionController appends it automatically
        jobName = name.hasSuffix(".pdf") ? String(name.dropLast(4)) : name
        printerName = printerID

        printInfo = PrintJob.makePrintInfo(jobName: jobName!, size: size, outputType: type)

        if dynamic {
            // UIKit drives the layout: numberOfPages asks Dart for the
            // document while the job runs.
            startJob()
            return
        }

        // Static layout: ask for the document first and start the job in
        // setDocument. The printer branch used to start the job here, before
        // anything had asked Dart for a document, so AirPrint got an empty
        // job and nothing printed.
        self.printing.onLayout(
            printJob: self,
            width: size.width,
            height: size.height,
            marginLeft: PrintJob.finite(margin.minX),
            marginTop: PrintJob.finite(margin.minY),
            marginRight: PrintJob.finite(size.width - margin.maxX),
            marginBottom: PrintJob.finite(size.height - margin.maxY)
        )
    }

    /// One print info per job, carrying exactly what Dart asked for.
    static func makePrintInfo(jobName: String, size: CGSize, outputType: UIPrintInfo.OutputType) -> UIPrintInfo {
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = jobName
        printInfo.outputType = outputType
        printInfo.orientation = size.width > size.height ? .landscape : .portrait
        return printInfo
    }

    /// Hand this renderer to UIKit, to a named printer or through the sheet.
    ///
    /// UIPrintInteractionController.shared is process-wide, so the print info
    /// and the renderer are re-assigned here, immediately before the job
    /// starts.
    private func startJob() {
        let controller = UIPrintInteractionController.shared
        controller.delegate = self
        if let printInfo {
            controller.printInfo = printInfo
        }
        controller.showsPaperSelectionForLoadedPapers = true
        controller.printPageRenderer = self

        guard let printerName else {
            if !controller.present(animated: true, completionHandler: completionHandler) {
                // Used to be silent, so the Dart future never completed.
                reportCompleted(false, "Unable to present the print sheet")
            }
            return
        }

        guard let printerURL = URL(string: printerName) else {
            reportCompleted(false, "Unable to find printer URL")
            return
        }

        let printerURLString = printerURL.absoluteString

        if !selectedPrinters.keys.contains(printerURLString) {
            selectedPrinters[printerURLString] = UIPrinter(url: printerURL)
        }

        // Sometimes using UIPrinter(url:) gives a non-contactable printer.
        // https://stackoverflow.com/questions/34602302/creating-a-working-uiprinter-object-from-url-for-dialogue-free-printing
        // This lets use a printer saved during picking and fall back using a printer created with UIPrinter(url:)
        if let pickedPrinter, selectedPrinters[printerURLString]!.url == pickedPrinter.url {
            if !controller.print(to: pickedPrinter, completionHandler: completionHandler) {
                reportCompleted(false, "Unable to start the print job")
            }
            return
        }

        selectedPrinters[printerURLString]!.contactPrinter { [weak self] available in
            guard let self else {
                return
            }

            if !available {
                self.reportCompleted(false, "Printer not available")
                return
            }

            if !controller.print(to: selectedPrinters[printerURLString]!, completionHandler: self.completionHandler) {
                self.reportCompleted(false, "Unable to start the print job")
            }
        }
    }

    /// 0 for a value that is not finite, so NaN never reaches Dart.
    static func finite(_ value: CGFloat) -> CGFloat {
        return value.isFinite ? value : 0
    }

    /// Replace an unspecified axis with the default paper's, so the job has a
    /// real sheet to lay out on.
    static func usableSize(_ size: CGSize) -> CGSize {
        // A4 in points, the same default the Dart side falls back to. The
        // print sheet lets the user pick another paper from here.
        let fallback = CGSize(width: 595.28, height: 841.89)
        let width = size.width.isFinite && size.width > 0 ? size.width : fallback.width
        let height = size.height.isFinite && size.height > 0 ? size.height : fallback.height
        return CGSize(width: width, height: height)
    }

    /// Clamp a margin rect to the sheet, dropping any non-finite edge.
    static func usableMargin(_ margin: CGRect, in size: CGSize) -> CGRect {
        let x = finite(margin.minX)
        let y = finite(margin.minY)
        let width = margin.width.isFinite ? margin.width : size.width - x
        let height = margin.height.isFinite ? margin.height : size.height - y
        return CGRect(x: x, y: y, width: max(0, width), height: max(0, height))
    }

    /// UIScene-safe key window lookup. `UIApplication.shared.keyWindow` and
    /// `UIApplication.shared.delegate.window` are nil under UISceneDelegate
    /// (deprecated in iOS 26, mandatory when building with the iOS 27 SDK), so
    /// resolve the key window from the connected window scenes instead.
    static func sceneKeyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            return windows.first(where: { $0.isKeyWindow }) ?? windows.first
        }
        // iOS < 13 has no UIScene; fall back to the app delegate's window.
        return UIApplication.shared.delegate?.window ?? nil
    }

    /// Offer the document through the share sheet.
    ///
    /// Returns false when nothing was presented, instead of letting the caller
    /// believe every share succeeded.
    static func sharePdf(data: Data, withSourceRect rect: CGRect, andName name: String, subject: String?, body: String?) -> Bool {
        // Defensive basename: a name carrying a separator pointed outside the
        // temp directory, and one carrying '..' escaped it.
        var safeName = (name as NSString).lastPathComponent
        if safeName.isEmpty || safeName == "." || safeName == ".." {
            safeName = "document.pdf"
        }

        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = tmpDirURL.appendingPathComponent(safeName)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("sharePdf error: \(error.localizedDescription)")
            return false
        }

        guard let controller = PrintJob.sceneKeyWindow()?.rootViewController else {
            // No window to present from: presenting would be a silent no-op.
            try? FileManager.default.removeItem(at: fileURL)
            return false
        }

        // A nil body used to be handed over as NSNull.
        var items: [Any] = [fileURL]
        if let body = body {
            items.append(body)
        }

        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.setValue(subject, forKey: "subject")
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
            // The share sheet has finished with the file; nothing used to
            // remove it.
            try? FileManager.default.removeItem(at: fileURL)
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityViewController.popoverPresentationController?.sourceView = controller.view
            activityViewController.popoverPresentationController?.sourceRect = rect
        }
        controller.present(activityViewController, animated: true)
        return true
    }

    func convertHtml(_ data: String, withPageSize rect: CGRect, andMargin margin: CGRect, andBaseUrl baseUrl: URL?) {
        // UIScene fix: delegate.window is nil under UISceneDelegate; force-
        // unwrapping it crashed convertHtml. Use the scene key window instead.
        let viewController = PrintJob.sceneKeyWindow()?.rootViewController
        guard let rootView = viewController?.view else {
            printing.onHtmlError(printJob: self, error: "No key window available to render HTML to PDF")
            return
        }
        let wkWebView = WKWebView(frame: rootView.bounds)
        wkWebView.isHidden = true
        wkWebView.tag = 100
        viewController?.view.addSubview(wkWebView)
        wkWebView.loadHTMLString(data, baseURL: baseUrl ?? Bundle.main.bundleURL)

        urlObservation = wkWebView.observe(\.isLoading, changeHandler: { _, _ in
            // this is workaround for issue with loading local images
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // assign the print formatter to the print page renderer
                let renderer = UIPrintPageRenderer()
                renderer.addPrintFormatter(wkWebView.viewPrintFormatter(), startingAtPageAt: 0)

                // assign paperRect and printableRect values
                renderer.setValue(rect, forKey: "paperRect")
                renderer.setValue(margin, forKey: "printableRect")

                // create pdf context and draw each page
                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, rect, nil)

                for i in 0 ..< renderer.numberOfPages {
                    UIGraphicsBeginPDFPage()
                    renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
                }

                UIGraphicsEndPDFContext()

                if let viewWithTag = viewController?.view.viewWithTag(wkWebView.tag) {
                    viewWithTag.removeFromSuperview() // remove hidden webview when pdf is generated

                    // clear WKWebView cache
                    if #available(iOS 9.0, *) {
                        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                            for record in records {
                                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                            }
                        }
                    }
                }

                // dispose urlObservation
                self.urlObservation = nil
                self.printing.onHtmlRendered(printJob: self, pdfData: pdfData as Data)
            }
        })
    }

    static func pickPrinter(result: @escaping FlutterResult, withSourceRect rect: CGRect) {
        let controller = UIPrinterPickerController(initiallySelectedPrinter: nil)

        let pickPrinterCompletionHandler: UIPrinterPickerController.CompletionHandler = {
            (printerPickerController: UIPrinterPickerController, completed: Bool, error: Error?) in
            if !completed, error != nil {
                print("Unable to pick printer: \(error?.localizedDescription ?? "unknown error")")
                result(nil)
                return
            }

            if printerPickerController.selectedPrinter == nil {
                result(nil)
                return
            }

            let printer = printerPickerController.selectedPrinter!
            // UIPrinter.url is non-optional in Swift but the underlying ObjC NSURL can be
            // nil for partially resolved printers (e.g. discovered over a personal hotspot);
            // force-bridging a nil NSURL to URL traps at runtime. Read it via KVC instead.
            guard let url = printer.value(forKey: "URL") as? URL else {
                result(nil)
                return
            }
            let data: NSDictionary = [
                "url": url.absoluteString as Any,
                "name": printer.displayName as Any,
                "model": printer.makeAndModel as Any,
                "location": printer.displayLocation as Any,
            ]

            pickedPrinter = printer

            result(data)
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            let viewController: UIViewController? = PrintJob.sceneKeyWindow()?.rootViewController
            if viewController != nil {
                controller.present(from: rect, in: viewController!.view, animated: true, completionHandler: pickPrinterCompletionHandler)
                return
            }
        }

        controller.present(animated: true, completionHandler: pickPrinterCompletionHandler)
    }

    public func rasterPdf(data: Data, pages: [Int]?, scale: CGFloat) {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            printing.onPageRasterEnd(printJob: self, error: "Cannot raster a malformed PDF file")
            return
        }

        DispatchQueue.global().async {
            // document is captured, so it outlives every page below.
            for pageNum in pages ?? Array(0 ... document.pageCount - 1) {
                guard let page = document.page(at: pageNum),
                      let raster = PdfPageRenderer.raster(page: page, scale: scale)
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
        return [
            "directPrint": true,
            "dynamicLayout": true,
            "canPrint": true,
            "canShare": true,
            "canRaster": true,
            "canListPrinters": false,
        ]
    }
}
