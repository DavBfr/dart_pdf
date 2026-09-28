# Apple page-renderer checks

`PdfPageRenderer.swift` exists verbatim in `macos/printing/Sources/printing/` and
`ios/printing/Sources/printing/`, because the two platform trees are separate
build targets and the file has to stay inside the plugin's single module: a
separate SwiftPM target could not be imported from a CocoaPods build.

The plugin's own package cannot be unit tested on its own, because it depends on
the Flutter framework that the Flutter tool supplies at build time. The renderer,
however, depends on nothing but PDFKit, so it can be compiled and exercised
directly:

```sh
python3 printing/test/apple/make_fixtures.py /tmp/printing-fixtures
swiftc -O -o /tmp/renderer-checks \
    printing/macos/printing/Sources/printing/PdfPageRenderer.swift \
    printing/test/apple/main.swift
/tmp/renderer-checks /tmp/printing-fixtures
diff printing/macos/printing/Sources/printing/PdfPageRenderer.swift \
     printing/ios/printing/Sources/printing/PdfPageRenderer.swift
```

`make_fixtures.py` writes six small PDFs by hand, so the box geometry and the
annotation dictionaries are exactly what the checks describe:

| fixture | what it pins |
|---|---|
| `crop_bl.pdf` | a CropBox whose origin is not the MediaBox origin |
| `offset.pdf` | a MediaBox whose origin is not (0, 0) |
| `rot90.pdf` | `/Rotate 90`, which swaps the raster axes |
| `crop_tr.pdf` | a CropBox flush with the MediaBox top-right corner |
| `annot.pdf` | an annotation with an `/AP /N` appearance stream |
| `hidden.pdf` | the same annotation with the Hidden flag set |

The four corner marks are red at the bottom-left, green at the bottom-right,
blue at the top-left and yellow at the top-right of the visible box, so a
displaced or clipped raster names itself.
