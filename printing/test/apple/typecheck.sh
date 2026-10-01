#!/bin/sh
#
# Type-check the iOS and macOS plugin sources on a machine with Xcode but no
# Flutter engine, by standing a minimal Flutter module in for the real one.
#
# Run from the repository root:
#
#   sh printing/test/apple/typecheck.sh
#
# This catches what `swiftc -parse` cannot: wrong UIKit, AppKit and PDFKit
# signatures. It is not a substitute for building the example app.
set -e

here=$(dirname "$0")
out=${TMPDIR:-/tmp}/printing-typecheck
rm -rf "$out"
mkdir -p "$out/ios" "$out/macos"

echo "--- iOS"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
target=arm64-apple-ios13.0-simulator
swiftc -emit-module -module-name Flutter -target "$target" -sdk "$sdk" \
    -emit-module-path "$out/ios/Flutter.swiftmodule" "$here/flutter_stub/Flutter.swift"
swiftc -typecheck -target "$target" -sdk "$sdk" -I "$out/ios" \
    "$here"/../../ios/printing/Sources/printing/*.swift

echo "--- macOS"
sdk=$(xcrun --sdk macosx --show-sdk-path)
target=arm64-apple-macos10.15
swiftc -emit-module -module-name FlutterMacOS -target "$target" -sdk "$sdk" \
    -emit-module-path "$out/macos/FlutterMacOS.swiftmodule" "$here/flutter_stub/FlutterMacOS.swift"
swiftc -typecheck -target "$target" -sdk "$sdk" -I "$out/macos" \
    "$here"/../../macos/printing/Sources/printing/*.swift

echo "--- ok"
