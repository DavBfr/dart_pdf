// The smallest stand-in for the Flutter iOS framework that lets the plugin's
// own sources be type-checked on a host with no Flutter engine. It declares
// only what printing/ios/printing/Sources/printing uses.
@_exported import Foundation
@_exported import UIKit

public typealias FlutterResult = (Any?) -> Void

public let FlutterMethodNotImplemented = NSObject()

public class FlutterError: NSObject {
    public let code: String
    public let message: String?
    public let details: Any?
    public init(code: String, message: String?, details: Any?) {
        self.code = code
        self.message = message
        self.details = details
    }
}

public class FlutterStandardTypedData: NSObject {
    public let data: Data
    public init(bytes: Data) { data = bytes }
}

public class FlutterMethodCall: NSObject {
    public let method: String
    public let arguments: Any?
    public init(methodName: String, arguments: Any?) {
        method = methodName
        self.arguments = arguments
    }
}

public protocol FlutterBinaryMessenger {}

public class FlutterMethodChannel: NSObject {
    public init(name _: String, binaryMessenger _: FlutterBinaryMessenger) {}
    public func invokeMethod(_: String, arguments _: Any?) {}
    public func invokeMethod(_: String, arguments _: Any?, result _: ((Any?) -> Void)?) {}
    public func setMethodCallHandler(_: ((FlutterMethodCall, @escaping FlutterResult) -> Void)?) {}
}

public protocol FlutterPlugin: NSObjectProtocol {
    static func register(with registrar: FlutterPluginRegistrar)
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
}

public protocol FlutterPluginRegistrar {
    func messenger() -> FlutterBinaryMessenger
    func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel)
}
