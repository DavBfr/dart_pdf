// Exercises the real PdfPageRenderer.swift against the fixtures that
// make_fixtures.py writes. See README.md in this directory for how to run it.
import Foundation
import PDFKit

let dir = CommandLine.arguments[1]
var failures = 0

func check(_ what: String, _ ok: Bool, _ detail: String = "") {
    if ok {
        print("ok   - \(what)")
    } else {
        print("FAIL - \(what) \(detail)")
        failures += 1
    }
}

// PDFPage does not retain its PDFDocument: drop the document and PDFKit logs
// "Drawing a PDFPage when its PDFDocument is nil is unsupported" and draws
// nothing. The plugin has to hold the document for as long as it draws, which
// is why these are kept here too.
var documents: [String: PDFDocument] = [:]

func page(_ name: String) -> PDFPage {
    if documents[name] == nil {
        documents[name] = PDFDocument(url: URL(fileURLWithPath: "\(dir)/\(name).pdf"))
    }
    guard let p = documents[name]?.page(at: 0) else {
        fatalError("cannot open \(name)")
    }
    return p
}

struct Raster {
    let data: Data
    let width: Int
    let height: Int

    /// The pixel at (x, y) counted from the TOP-LEFT, as the channel delivers it.
    ///
    /// Row 0 of a CGBitmapContext's buffer is the top of the image, even though
    /// the drawing origin is its bottom-left.
    func pixel(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let i = y * width * 4 + x * 4
        return (data[i], data[i + 1], data[i + 2], data[i + 3])
    }

    func name(_ x: Int, _ y: Int) -> String {
        let (r, g, b, a) = pixel(x, y)
        if a < 128 { return "clear" }
        func near(_ v: UInt8, _ t: UInt8) -> Bool { abs(Int(v) - Int(t)) < 40 }
        if near(r, 255), near(g, 0), near(b, 0) { return "red" }
        if near(r, 0), near(g, 255), near(b, 0) { return "green" }
        if near(r, 0), near(g, 0), near(b, 255) { return "blue" }
        if near(r, 255), near(g, 255), near(b, 0) { return "yellow" }
        if near(r, 128), near(g, 128), near(b, 128) { return "grey" }
        if near(r, 255), near(g, 255), near(b, 255) { return "white" }
        return "rgba(\(r),\(g),\(b),\(a))"
    }
}

func raster(_ name: String, scale: CGFloat = 1, background: UInt32 = 0xFFFF_FFFF) -> Raster {
    guard let r = PdfPageRenderer.raster(page: page(name), scale: scale, background: background)
    else {
        fatalError("raster failed for \(name)")
    }
    return Raster(data: r.data, width: r.width, height: r.height)
}

// --- sizes -----------------------------------------------------------------

// A crop box whose origin is not the media origin: exactly the crop region.
let cropBl = raster("crop_bl")
check("crop_bl rasters to 100x100", cropBl.width == 100 && cropBl.height == 100,
      "got \(cropBl.width)x\(cropBl.height)")

// A media box whose origin is not zero.
let offset = raster("offset")
check("offset rasters to 200x200", offset.width == 200 && offset.height == 200,
      "got \(offset.width)x\(offset.height)")

// A quarter turn swaps the axes.
let rot = raster("rot90")
check("rot90 rasters to 100x200", rot.width == 100 && rot.height == 200,
      "got \(rot.width)x\(rot.height)")

// The case that already worked must keep working.
let cropTr = raster("crop_tr")
check("crop_tr rasters to 100x100", cropTr.width == 100 && cropTr.height == 100,
      "got \(cropTr.width)x\(cropTr.height)")

// Rounded, not truncated: 100pt at 1.004 is 100.4, which used to lose a column.
let rounded = PdfPageRenderer.rasterSize(of: page("crop_bl"), scale: 1.006)
check("a non-integral scale rounds up", rounded.width == 101 && rounded.height == 101,
      "got \(rounded.width)x\(rounded.height)")

// --- content position ------------------------------------------------------

// The four corner marks name themselves. Top-left is blue, and it must be at
// the very corner of the raster: a missing origin translation put grey there.
for (name, r) in [("crop_bl", cropBl), ("offset", offset), ("crop_tr", cropTr)] {
    check("\(name) top-left corner is blue", r.name(2, 2) == "blue", "got \(r.name(2, 2))")
    check("\(name) top-right corner is yellow", r.name(r.width - 3, 2) == "yellow",
          "got \(r.name(r.width - 3, 2))")
    check("\(name) bottom-left corner is red", r.name(2, r.height - 3) == "red",
          "got \(r.name(2, r.height - 3))")
    check("\(name) bottom-right corner is green",
          r.name(r.width - 3, r.height - 3) == "green",
          "got \(r.name(r.width - 3, r.height - 3))")
}

// A 90 degree turn moves bottom-left (red) to the top-left.
check("rot90 top-left corner is red", rot.name(2, 2) == "red", "got \(rot.name(2, 2))")
check("rot90 content reaches every corner",
      rot.name(rot.width - 3, 2) != "clear"
          && rot.name(2, rot.height - 3) != "clear"
          && rot.name(rot.width - 3, rot.height - 3) != "clear")

// --- annotations -----------------------------------------------------------

// The appearance stream paints the top-right quadrant red. drawPDFPage never
// composited it.
let annot = raster("annot")
check("an annotation appearance is drawn", annot.name(75, 25) == "red",
      "got \(annot.name(75, 25))")
check("the rest of the page is untouched", annot.name(25, 75) == "white",
      "got \(annot.name(25, 75))")

// A Hidden annotation (/F bit 2) stays hidden.
let hidden = raster("hidden")
check("a hidden annotation is not drawn", hidden.name(75, 25) == "white",
      "got \(hidden.name(75, 25))")

// --- scale -----------------------------------------------------------------

let scaled = raster("crop_bl", scale: 2)
check("scale 2 doubles the raster", scaled.width == 200 && scaled.height == 200,
      "got \(scaled.width)x\(scaled.height)")
check("scale 2 keeps the corners", scaled.name(4, 4) == "blue", "got \(scaled.name(4, 4))")

// --- page backdrop ------------------------------------------------------------

// A PDF page has no background of its own. Nothing painted one, so a rastered
// page came back transparent and saving it as PNG gave a black page.
let opaque = raster("blank")
check("a blank page is opaque white by default", opaque.name(5, 5) == "white",
      "got \(opaque.name(5, 5))")
check("every pixel of it is opaque", {
    for y in 0 ..< opaque.height {
        for x in 0 ..< opaque.width {
            if opaque.pixel(x, y).3 != 255 { return false }
        }
    }
    return true
}())

// The 5.17 and earlier output: nothing behind the page at all.
let clear = raster("blank", background: 0x0000_0000)
check("a zero background paints nothing", clear.name(5, 5) == "clear",
      "got \(clear.name(5, 5))")

// An explicit colour, to prove the channels are not swapped.
let blue = raster("blank", background: 0xFF00_00FF)
check("an explicit background keeps its channels", blue.name(5, 5) == "blue",
      "got \(blue.name(5, 5))")
let half = raster("blank", background: 0x8000_0000)
let (hr, hg, hb, ha) = half.pixel(5, 5)
check("a translucent background is premultiplied",
      ha == 128 && hr == 0 && hg == 0 && hb == 0,
      "got rgba(\(hr),\(hg),\(hb),\(ha))")

// The backdrop goes behind the content, not over it.
let overCrop = raster("crop_bl")
check("the backdrop does not cover the page", overCrop.name(2, 2) == "blue",
      "got \(overCrop.name(2, 2))")

print(failures == 0 ? "\nPdfPageRenderer: all checks passed"
                    : "\n\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
