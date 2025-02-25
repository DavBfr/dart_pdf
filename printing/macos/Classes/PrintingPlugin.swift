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

@objc
public class PrintingPlugin: NSObject, FlutterPlugin {
    private static var instance: PrintingPlugin?
    private var channel: FlutterMethodChannel
    public var jobs = [UInt32: PrintJob]()
    private var registrar: FlutterPluginRegistrar

    init(_ channel: FlutterMethodChannel, _ registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
        super.init()
        PrintingPlugin.instance = self
    }

    @objc
    public static func setDocument(job: UInt32, doc: UnsafePointer<UInt8>, size: UInt64) {
        instance!.jobs[job]?.setDocument(Data(bytes: doc, count: Int(size)))
    }

    @objc
    public static func setError(job: UInt32, message: UnsafePointer<CChar>) {
        instance!.jobs[job]?.cancelJob(String(cString: message))
    }

    /// Entry point
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "net.nfet.printing", binaryMessenger: registrar.messenger)
        let instance = PrintingPlugin(channel, registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Flutter method handlers
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments! as! [String: Any]
        if call.method == "printPdf" {
            let name = args["name"] as! String
            let printer = args["printer"] as? String
            let width = CGFloat((args["width"] as! NSNumber).floatValue)
            let height = CGFloat((args["height"] as! NSNumber).floatValue)
            let marginLeft = CGFloat((args["marginLeft"] as! NSNumber).floatValue)
            let marginTop = CGFloat((args["marginTop"] as! NSNumber).floatValue)
            let marginRight = CGFloat((args["marginRight"] as! NSNumber).floatValue)
            let marginBottom = CGFloat((args["marginBottom"] as! NSNumber).floatValue)
            let printJob = PrintJob(printing: self, index: args["job"] as! Int)
            let dynamic = args["dynamic"] as! Bool
            jobs[args["job"] as! UInt32] = printJob

            guard let window = registrar.view?.window else {
                result(NSNumber(value: 0))
                onCompleted(printJob: printJob, completed: false, error: "Unable to find the main window")
                return
            }

            printJob.printPdf(name: name,
                              withPageSize: CGSize(
                                  width: width,
                                  height: height
                              ),
                              andMargin: CGRect(
                                  x: marginLeft,
                                  y: marginTop,
                                  width: width - marginRight - marginLeft,
                                  height: height - marginBottom - marginTop
                              ), withPrinter: printer,
                              dynamically: dynamic, andWindow: window)
            result(NSNumber(value: 1))
        } else if call.method == "listPrinters" {
            let printJob = PrintJob(printing: self, index: -1)
            let r = printJob.listPrinters()
            result(r)
        } else if call.method == "sharePdf" {
            let object = args["doc"] as! FlutterStandardTypedData

            guard let view = registrar.view else {
                result(NSNumber(value: 0))
                return
            }

            PrintJob.sharePdf(
                data: object.data,
                withSourceRect: CGRect(
                    x: CGFloat((args["x"] as? NSNumber)?.floatValue ?? 0.0),
                    y: CGFloat((args["y"] as? NSNumber)?.floatValue ?? 0.0),
                    width: CGFloat((args["w"] as? NSNumber)?.floatValue ?? 0.0),
                    height: CGFloat((args["h"] as? NSNumber)?.floatValue ?? 0.0)
                ),
                andName: args["name"] as! String, andWindow: view
            )
            result(NSNumber(value: 1))
        } else if call.method == "convertHtml" {
            let width = CGFloat((args["width"] as? NSNumber)?.floatValue ?? 0.0)
            let height = CGFloat((args["height"] as? NSNumber)?.floatValue ?? 0.0)
            let marginLeft = CGFloat((args["marginLeft"] as? NSNumber)?.floatValue ?? 0.0)
            let marginTop = CGFloat((args["marginTop"] as? NSNumber)?.floatValue ?? 0.0)
            let marginRight = CGFloat((args["marginRight"] as? NSNumber)?.floatValue ?? 0.0)
            let marginBottom = CGFloat((args["marginBottom"] as? NSNumber)?.floatValue ?? 0.0)
            let printJob = PrintJob(printing: self, index: args["job"] as! Int)

            if #available(macOS 11.0, *) {
                printJob.convertHtml(
                    args["html"] as! String,
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
                    andBaseUrl: args["baseUrl"] as? String == nil ? nil : URL(string: args["baseUrl"] as! String)
                )
                result(NSNumber(value: 1))
            } else {
                result(NSNumber(value: 0))
            }
        } else if call.method == "printingInfo" {
            result(PrintJob.printingInfo())
        } else if call.method == "rasterPdf" {
            let doc = args["doc"] as! FlutterStandardTypedData
            let pages = args["pages"] as? [Int]
            let scale = CGFloat((args["scale"] as! NSNumber).floatValue)
            let printJob = PrintJob(printing: self, index: args["job"] as! Int)
            printJob.rasterPdf(data: doc.data,
                               pages: pages,
                               scale: scale)
            result(NSNumber(value: 1))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Request the Pdf document from flutter
    public func onLayout(printJob: PrintJob, width: CGFloat, height: CGFloat, marginLeft: CGFloat, marginTop: CGFloat, marginRight: CGFloat, marginBottom: CGFloat) {
        let arg = [
            "width": width,
            "height": height,
            "marginLeft": marginLeft,
            "marginTop": marginTop,
            "marginRight": marginRight,
            "marginBottom": marginBottom,
            "job": printJob.index,
        ] as [String: Any]

        channel.invokeMethod("onLayout", arguments: arg)
    }

    /// send completion status to flutter
    public func onCompleted(printJob: PrintJob, completed: Bool, error: NSString?) {
        let data: NSDictionary = [
            "completed": completed,
            "error": error as Any,
            "job": printJob.index,
        ]
        channel.invokeMethod("onCompleted", arguments: data)
        jobs.removeValue(forKey: UInt32(printJob.index))
    }

    /// send html to pdf data result to flutter
    public func onHtmlRendered(printJob: PrintJob, pdfData: Data) {
        let data: NSDictionary = [
            "doc": FlutterStandardTypedData(bytes: pdfData),
            "job": printJob.index,
        ]
        channel.invokeMethod("onHtmlRendered", arguments: data)
    }

    /// send html to pdf conversion error to flutter
    public func onHtmlError(printJob: PrintJob, error: String) {
        let data: NSDictionary = [
            "error": error,
            "job": printJob.index,
        ]
        channel.invokeMethod("onHtmlError", arguments: data)
    }

    /// send pdf to raster data result to flutter
    public func onPageRasterized(printJob: PrintJob, imageData: Data, width: Int, height: Int) {
        let data: NSDictionary = [
            "image": FlutterStandardTypedData(bytes: imageData),
            "width": width,
            "height": height,
            "job": printJob.index,
        ]
        channel.invokeMethod("onPageRasterized", arguments: data)
    }

    public func onPageRasterEnd(printJob: PrintJob, error: String?) {
        let data: NSDictionary = [
            "job": printJob.index,
            "error": error as Any,
        ]
        channel.invokeMethod("onPageRasterEnd", arguments: data)
    }
}
