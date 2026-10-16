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

import CoreGraphics
import PDFKit

/// Geometry and drawing for one PDF page.
///
/// This file has no Flutter dependency and exists verbatim in the iOS and the
/// macOS tree, which are separate build targets. Keep the two copies identical.
///
/// PDFKit rather than `CGContext.drawPDFPage`, for two reasons:
///
/// * `drawPDFPage` runs only the page's content stream, so annotation
///   appearance streams - highlights, comments, ink, stamps, form widgets -
///   were silently missing from every rastered and printed page on Apple
///   platforms, while the pdfium backends drew them. `PDFPage.draw(with:to:)`
///   composites them, and honours the Hidden flag.
/// * `drawPDFPage` applies no transform for the page box origin, so a page
///   whose MediaBox or CropBox origin is not (0, 0) drew displaced and clipped.
///   PDFKit puts the requested box at the context origin.
enum PdfPageRenderer {
    /// How `page` is presented, in points, with `/Rotate` applied.
    ///
    /// `PDFPage.bounds(for:)` is in unrotated page space, so a quarter turn
    /// swaps the axes.
    static func size(of page: PDFPage, for box: PDFDisplayBox = .cropBox) -> CGSize {
        let bounds = page.bounds(for: box)
        let quarterTurns = ((page.rotation % 360) + 360) % 360

        return quarterTurns == 90 || quarterTurns == 270
            ? CGSize(width: bounds.height, height: bounds.width)
            : bounds.size
    }

    /// The pixel size of `page` rastered at `scale`, at least one pixel each way.
    ///
    /// Rounded rather than truncated: truncating lost the last row or column of
    /// a page whose scaled size was not integral, and iOS and macOS disagreed
    /// about the size of the same document because one sized from the media box
    /// and the other from the crop box.
    static func rasterSize(of page: PDFPage, scale: CGFloat) -> (width: Int, height: Int) {
        let size = self.size(of: page)

        return (
            width: max(Int((size.width * scale).rounded()), 1),
            height: max(Int((size.height * scale).rounded()), 1)
        )
    }

    /// Paint the page backdrop.
    ///
    /// A PDF page has no background of its own: the imaging model leaves it to
    /// whatever displays the document. Nothing painted one here, so a rastered
    /// page came back transparent - 96% of a blank A4 at alpha 0 - and saving it
    /// as PNG or re-encoding it as JPEG gave a black page.
    ///
    /// `argb` is 0xAARRGGBB; a zero alpha paints nothing, which is what printing
    /// 5.17 and earlier produced.
    static func fill(_ argb: UInt32, in context: CGContext, to rect: CGRect) {
        let alpha = CGFloat((argb >> 24) & 0xFF) / 255
        guard alpha > 0 else {
            return
        }

        context.saveGState()
        // Unpremultiplied components: CoreGraphics premultiplies into the
        // bitmap, which is what ui.decodeImageFromPixels expects to receive.
        context.setFillColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: alpha
        )
        context.fill(rect)
        context.restoreGState()
    }

    /// Draw `page` into `context`, fitted inside `rect` and centred.
    ///
    /// `context` must use PDF conventions, with y increasing upwards.
    static func draw(
        page: PDFPage,
        in context: CGContext,
        to rect: CGRect,
        for box: PDFDisplayBox = .cropBox
    ) {
        let size = self.size(of: page, for: box)
        guard size.width > 0, size.height > 0, !rect.isEmpty else {
            return
        }

        // Fitted, so a page larger than the destination scales down instead of
        // being clipped.
        let scale = min(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)

        context.saveGState()
        context.translateBy(
            x: rect.minX + (rect.width - drawn.width) / 2,
            y: rect.minY + (rect.height - drawn.height) / 2
        )
        context.scaleBy(x: scale, y: scale)
        // PDFKit maps the box onto the origin and applies the rotation, so this
        // is the whole transform.
        page.draw(with: box, to: context)
        context.restoreGState()
    }

    /// Raster `page` at `scale` into premultiplied RGBA bytes.
    ///
    /// `background` is the 0xAARRGGBB page backdrop, opaque white by default.
    ///
    /// Returns nil when the bitmap context cannot be created.
    static func raster(
        page: PDFPage,
        scale: CGFloat,
        background: UInt32 = 0xFFFF_FFFF
    ) -> (data: Data, width: Int, height: Int)? {
        let (width, height) = rasterSize(of: page, scale: scale)
        let stride = width * 4
        var data = Data(repeating: 0, count: stride * height)

        let drawn = data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: stride,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else {
                return false
            }

            let bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            fill(background, in: context, to: bounds)
            draw(page: page, in: context, to: bounds)
            return true
        }

        return drawn ? (data: data, width: width, height: height) : nil
    }
}
