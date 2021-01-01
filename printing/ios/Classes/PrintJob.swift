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
import WebKit

func dataProviderReleaseDataCallback(info _: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size _: Int) {
    data.deallocate()
}

public class PrintJob: UIPrintPageRenderer, UIPrintInteractionControllerDelegate {
    private var printing: PrintingPlugin
    public var index: Int
    private var pdfDocument: CGPDFDocument?
    private var urlObservation: NSKeyValueObservation?
    private var jobName: String?
    private var orientation: UIPrintInfo.Orientation?

    public init(printing: PrintingPlugin, index: Int) {
        self.printing = printing
        self.index = index
        pdfDocument = nil
        super.init()
    }

    override public func drawPage(at pageIndex: Int, in _: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        let page = pdfDocument?.page(at: pageIndex + 1)
        ctx?.scaleBy(x: 1.0, y: -1.0)
        ctx?.translateBy(x: 0.0, y: -paperRect.size.height)
        if page != nil {
            ctx?.drawPDFPage(page!)
        }
    }

    func cancelJob(_ error: String?) {
        pdfDocument = nil
        printing.onCompleted(printJob: self, completed: false, error: error as NSString?)
    }

    func setDocument(_ data: Data?) {
        let bytesPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data?.count ?? 0)
        data?.copyBytes(to: bytesPointer, count: data?.count ?? 0)
        let dataProvider = CGDataProvider(dataInfo: nil, data: bytesPointer, size: data?.count ?? 0, releaseData: dataProviderReleaseDataCallback)
        pdfDocument = CGPDFDocument(dataProvider!)

        let controller = UIPrintInteractionController.shared
        controller.delegate = self

        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = jobName!
        printInfo.outputType = .general
        if orientation != nil {
            printInfo.orientation = orientation!
            orientation = nil
        }
        controller.printInfo = printInfo
        controller.printPageRenderer = self
        controller.present(animated: true, completionHandler: completionHandler)
    }

    override public var numberOfPages: Int {
        let pages = pdfDocument?.numberOfPages ?? 0
        return pages
    }

    func completionHandler(printController _: UIPrintInteractionController, completed: Bool, error: Error?) {
        if !completed, error != nil {
            print("Unable to print: \(error?.localizedDescription ?? "unknown error")")
        }

        printing.onCompleted(printJob: self, completed: completed, error: error?.localizedDescription as NSString?)
    }

    func directPrintPdf(name: String, data: Data, withPrinter printerID: String) {
        let printing = UIPrintInteractionController.isPrintingAvailable
        if !printing {
            self.printing.onCompleted(printJob: self, completed: false, error: "Printing not available")
            return
        }

        let controller = UIPrintInteractionController.shared

        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = name
        printInfo.outputType = .general
        controller.printInfo = printInfo
        controller.printingItem = data
        let printerURL = URL(string: printerID)

        if printerURL == nil {
            self.printing.onCompleted(printJob: self, completed: false, error: "Unable to find printer URL")
            return
        }

        let printer = UIPrinter(url: printerURL!)
        controller.print(to: printer, completionHandler: completionHandler)
    }

    func printPdf(name: String, withPageSize size: CGSize, andMargin margin: CGRect) {
        let printing = UIPrintInteractionController.isPrintingAvailable
        if !printing {
            self.printing.onCompleted(printJob: self, completed: false, error: "Printing not available")
            return
        }

        if size.width > size.height {
            orientation = UIPrintInfo.Orientation.landscape
        }

        jobName = name

        self.printing.onLayout(
            printJob: self,
            width: size.width,
            height: size.height,
            marginLeft: margin.minX,
            marginTop: margin.minY,
            marginRight: size.width - margin.maxX,
            marginBottom: size.height - margin.maxY
        )
    }

    static func sharePdf(data: Data, withSourceRect rect: CGRect, andName name: String) {
        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = tmpDirURL.appendingPathComponent(name)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("sharePdf error: \(error.localizedDescription)")
            return
        }

        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if UI_USER_INTERFACE_IDIOM() == .pad {
            let controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
            activityViewController.popoverPresentationController?.sourceView = controller?.view
            activityViewController.popoverPresentationController?.sourceRect = rect
        }
        UIApplication.shared.keyWindow?.rootViewController?.present(activityViewController, animated: true)
    }

    func convertHtml(_ data: String, withPageSize rect: CGRect, andMargin margin: CGRect, andBaseUrl baseUrl: URL?) {
        let viewController = UIApplication.shared.delegate?.window?!.rootViewController
        let wkWebView = WKWebView(frame: viewController!.view.bounds)
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
                            records.forEach { record in
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
            let data: NSDictionary = [
                "url": printer.url.absoluteString as Any,
                "name": printer.displayName as Any,
                "model": printer.makeAndModel as Any,
                "location": printer.displayLocation as Any,
            ]
            result(data)
        }

        if UI_USER_INTERFACE_IDIOM() == .pad {
            let viewController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
            if viewController != nil {
                controller.present(from: rect, in: viewController!.view, animated: true, completionHandler: pickPrinterCompletionHandler)
                return
            }
        }

        controller.present(animated: true, completionHandler: pickPrinterCompletionHandler)
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
            "directPrint": true,
            "dynamicLayout": false,
            "canPrint": true,
            "canConvertHtml": true,
            "canShare": true,
            "canRaster": true,
        ]
        return data
    }
}
