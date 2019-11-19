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
import UIKit
import WebKit

public class SwiftPrintingPlugin: NSObject, FlutterPlugin, UIPrintInteractionControllerDelegate {
    private var channel: FlutterMethodChannel?
    private var renderer: PdfPrintPageRenderer?
    private var urlObservation: NSKeyValueObservation?

    init(_ channel: FlutterMethodChannel?) {
        super.init()
        self.channel = channel
        renderer = nil
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "net.nfet.printing", binaryMessenger: registrar.messenger())
        let instance = SwiftPrintingPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments! as! [String: Any]
        if call.method == "printPdf" {
            let name = args["name"] as? String ?? ""
            let object = args["doc"] as? FlutterStandardTypedData
            printPdf(name, data: object?.data)
            result(NSNumber(value: 1))
        } else if call.method == "directPrintPdf" {
            let name = args["name"] as? String ?? ""
            let printer = args["printer"] as? String
            let object = args["doc"] as? FlutterStandardTypedData
            directPrintPdf(name: name, data: object!.data, withPrinter: printer!)
            result(NSNumber(value: 1))
        } else if call.method == "writePdf" {
            if let object = args["doc"] as? FlutterStandardTypedData {
                writePdf(object.data)
            }
            result(NSNumber(value: 1))
        } else if call.method == "cancelJob" {
            renderer?.cancelJob()
            let controller = UIPrintInteractionController.shared
            controller.dismiss(animated: true)
            result(NSNumber(value: 1))
        } else if call.method == "sharePdf" {
            if let object = args["doc"] as? FlutterStandardTypedData {
                sharePdf(
                    object,
                    withSourceRect: CGRect(x: CGFloat((args["x"] as? NSNumber)?.floatValue ?? 0.0), y: CGFloat((args["y"] as? NSNumber)?.floatValue ?? 0.0), width: CGFloat((args["w"] as? NSNumber)?.floatValue ?? 0.0), height: CGFloat((args["h"] as? NSNumber)?.floatValue ?? 0.0)),
                    andName: args["name"] as? String
                )
            }
            result(NSNumber(value: 1))
        } else if call.method == "convertHtml" {
            let width = CGFloat((args["width"] as? NSNumber)?.floatValue ?? 0.0)
            let height = CGFloat((args["height"] as? NSNumber)?.floatValue ?? 0.0)
            let marginLeft = CGFloat((args["marginLeft"] as? NSNumber)?.floatValue ?? 0.0)
            let marginTop = CGFloat((args["marginTop"] as? NSNumber)?.floatValue ?? 0.0)
            let marginRight = CGFloat((args["marginRight"] as? NSNumber)?.floatValue ?? 0.0)
            let marginBottom = CGFloat((args["marginBottom"] as? NSNumber)?.floatValue ?? 0.0)
            convertHtml(
                (args["html"] as? String)!,
                withPageSize: CGRect(
                    x: 0.0,
                    y: 0.0,
                    width: width,
                    height: height
                ),
                andMargin: CGRect(
                    x: marginLeft,
                    y: marginTop,
                    width: width - marginRight - marginLeft,
                    height: height - marginBottom - marginTop
                ),
                andBaseUrl: args["baseUrl"] as? String == nil ? nil : URL(string: (args["baseUrl"] as? String)!)
            )
            result(NSNumber(value: 1))
        } else if call.method == "pickPrinter" {
            pickPrinter(result, withSourceRect: CGRect(
                x: CGFloat((args["x"] as? NSNumber)?.floatValue ?? 0.0),
                y: CGFloat((args["y"] as? NSNumber)?.floatValue ?? 0.0),
                width: CGFloat((args["w"] as? NSNumber)?.floatValue ?? 0.0),
                height: CGFloat((args["h"] as? NSNumber)?.floatValue ?? 0.0)
            ))
        } else if call.method == "printingInfo" {
            let data: NSDictionary = [
                "iosVersion": UIDevice.current.systemVersion,
            ]
            result(data)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    func completionHandler(printController _: UIPrintInteractionController, completed: Bool, error: Error?) {
        if !completed, error != nil {
            print("Unable to print: \(error?.localizedDescription ?? "unknown error")")
        }

        let data: NSDictionary = [
            "completed": completed,
            "error": error?.localizedDescription as Any,
        ]
        channel?.invokeMethod("onCompleted", arguments: data)

        renderer = nil
    }

    func directPrintPdf(name: String, data: Data, withPrinter printerID: String) {
        let printing = UIPrintInteractionController.isPrintingAvailable
        if !printing {
            let data: NSDictionary = [
                "completed": false,
                "error": "Printing not available",
            ]
            channel?.invokeMethod("onCompleted", arguments: data)
            return
        }

        let controller = UIPrintInteractionController.shared
        controller.delegate = self

        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = name
        printInfo.outputType = .general
        controller.printInfo = printInfo
        controller.printingItem = data
        let printerURL = URL(string: printerID)

        if printerURL == nil {
            let data: NSDictionary = [
                "completed": false,
                "error": "Unable to fine printer URL",
            ]
            channel?.invokeMethod("onCompleted", arguments: data)
            return
        }

        let printer = UIPrinter(url: printerURL!)
        controller.print(to: printer, completionHandler: completionHandler)
    }

    func printPdf(_ name: String, data: Data?) {
        let printing = UIPrintInteractionController.isPrintingAvailable
        if !printing {
            let data: NSDictionary = [
                "completed": false,
                "error": "Printing not available",
            ]
            channel?.invokeMethod("onCompleted", arguments: data)
            return
        }

        let controller = UIPrintInteractionController.shared
        controller.delegate = self

        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = name
        printInfo.outputType = .general
        controller.printInfo = printInfo
        renderer = PdfPrintPageRenderer(channel, data: data)
        controller.printPageRenderer = renderer
        controller.present(animated: true, completionHandler: completionHandler)
    }

    func writePdf(_ data: Data) {
        renderer?.setDocument(data)
    }

    func sharePdf(_ data: FlutterStandardTypedData, withSourceRect rect: CGRect, andName name: String?) {
        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let uuid = CFUUIDCreate(nil)
        assert(uuid != nil)

        let uuidStr = CFUUIDCreateString(nil, uuid)
        assert(uuidStr != nil)

        var fileURL: URL
        if name == nil {
            fileURL = tmpDirURL.appendingPathComponent("document-\(uuidStr ?? "1" as CFString)").appendingPathExtension("pdf")
        } else {
            fileURL = tmpDirURL.appendingPathComponent(name!)
        }

        do {
            try data.data.write(to: fileURL, options: .atomic)
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

                let data = FlutterStandardTypedData(bytes: pdfData as Data)
                self.channel?.invokeMethod("onHtmlRendered", arguments: data)
            }
        })
    }

    func pickPrinter(_ result: @escaping FlutterResult, withSourceRect rect: CGRect) {
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
}
