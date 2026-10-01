# Changelog

## 3.19.0

- **Fix widgets sharing a field name becoming several top-level fields with conflicting values.** Every widget annotation was its own merged field-and-widget dictionary and every one was listed in `/AcroForm` `/Fields`, so a `TextField` or `Checkbox` in a `MultiPage` header produced one root field per page - the same `/T`, a different `/V` each. Acrobat listed the name once per page, an FDF export held one entry each, and validators flagged the file. ISO 32000-1 12.7.3.1 permits the merged form only for a single-widget field, so widgets sharing a name are now kids of one field: the field carries `/T`, `/FT`, `/V` and `/DV`, each kid carries `/Parent` and keeps its own `/Rect`, `/P`, `/AP` and `/AS`. **A document whose field names are all unique is unchanged**, and a signature stays a root field
- `PdfAcroFormField` is new; `PdfAnnotWidget` gains `fieldParent` and `PdfDocument` a protected `prepareAcroForm()`
- **Fix a `ChoiceField`'s `/DA` naming a font declared in no `/DR`.** The `/DR` collector only recognised a `PdfTextField`, and the field's own font registration ran after `PdfPage.prepare` had already frozen `/Resources` - so the font appeared in neither, and Acrobat regenerated the appearance with Helvetica: CJK and Arabic option text came out as boxes. Every widget that writes a `/DA` now contributes its font, through the new `PdfAnnotBase.defaultAppearanceFonts`. A document with only text fields is byte-identical
- **Fix a widget annotation's `/T` being written from the author.** `/T` is defined only for a markup annotation (ISO 32000-1 12.5.6.4); on a merged field dictionary it is the partial field name. So a `PdfAnnotWidget`, `PdfFormField` or `PdfTextField` given an `author` and no `fieldName` became a form field named after the author - an FDF export carried `Jane Doe=hello` - and with both set one silently won. The author is now written only on a markup annotation; `author` on the widget classes is marked deprecated and does nothing
- **Fix writing the same `PdfDocument` twice producing a larger, malformed file.** `prepare()` runs on every write and five implementations appended to state that survives the call, so a second write embedded the font program again behind a `/Length1` that described one copy, gave `/ToUnicode` two `begincmap` programs, and listed every width and every annotation twice - 7,214 bytes became 12,887. `prepare()` is now idempotent rather than gated, so an object mutated between writes still serialises: the font program, the CMap and the sampled function rebuild their buffers, the width array is cleared, and `/Annots` is built the way `/Contents` already was, by merging and then deduplicating. Three consecutive writes are byte-identical, and a `/Contents` or `/Annots` inherited from a template survives, once
- `PdfStream` gains `reset()`
- **Fix content added with `editPage` inheriting the imported page's graphics state.** ISO 32000-1 7.8.2 concatenates a `/Contents` array into one stream, so a top-level flip or an unbalanced `q` left by the file's producer was still in force for whatever was stamped on afterwards - text and images came out mirrored, rotated or offset, depending on which tool wrote the file, with no error (#1657). The imported entries are now bracketed with a `q` and a `Q` stream, so appended content starts from the default state. `PdfPage` gains `protectImportedContents`, default true; a loaded page nothing is stamped onto is untouched
- **Fix `/MediaBox` always being written as `[0 0 w h]`, discarding a non-zero page origin.** Loading a PDF whose box has a negative origin and re-saving it pinned the box to 0,0, so the imported content at negative coordinates fell off the page and typically one quadrant survived (#1572). `PdfPage` gains an `origin`, default (0,0) and byte-identical there, and the box is derived from it on every write. A non-zero origin also drops an inherited `/CropBox`, which was written in the source page's coordinates and could otherwise name a region outside the box
- **Fix a non-BMP character becoming two `U+FFFD` in every `PdfString`.** The UTF-16BE encoder walked `str.codeUnits` while its branch conditions were written for code points, so every surrogate fell through to the replacement-character branch: an emoji in `Document(title:)`, in an outline title, in a named destination, in an annotation's contents or in a form field value came out as `??`. It now walks `str.runes`. ASCII and Latin-1 keep the fast path with no BOM, and a BMP string is byte-identical; **only strings that were corrupt change**, so the `/Info` and bookmark bytes of those documents move
- **Fix `PdfName` escaping UTF-16 code units rather than bytes.** Each code unit was treated as a PDF byte, so an acute accent gave `/Acc#e9nt` instead of `/Acc#c3#a9nt`, a CJK character gave `#4e2d` - five characters where a `#` must be followed by exactly two hex digits, so the name reads back as something else - and a non-BMP character emitted both of its surrogate halves. The assert also rejected `0xFF`, which is a legal name byte, so a debug build crashed where release wrote the malformed name. Names are now escaped over their UTF-8 bytes, and a null byte - which ISO 32000-1 7.3.5 prohibits - throws a `PdfException` naming the value. ASCII is unchanged
- **Fix `PdfStream.putStream` copying the whole backing buffer.** It appended the source's raw array rather than the bytes written to it, and the buffer grows in 64KB steps - so splicing a three-byte stream produced 65536 bytes, 65533 of them NUL, and splicing a saved document left NULs after its `%%EOF`
- **Fix the xref stream's `/W` offset field being one byte too narrow at a power of 256.** The width came from `ceil(log2(x)) / 8`, and `ceil(log2)` is one bit short for a power of two, which crosses a byte boundary at 2^8, 2^16 and 2^24. The xref stream's own offset is the largest in the table, so a document whose xref began exactly at byte 65536 recorded it as `65536 & 0xFFFF`, which is 0: validators flagged the file and readers rebuilt the table. The width is now computed exactly, over every offset in the table. Output is identical for every offset that is not a power of 256

## 3.18.0

- **Fix `<text>` with a `<tspan>` drawing its runs out of order and in the wrong place.** Every text node of a `<text>` was joined and trimmed into one string, and each child element became a `<tspan>` drawn afterwards - so `AB<tspan>CD</tspan>EF` drew `ABEF` and then `CD` after the whole parent string, the space before a `<tspan>` was dropped, source newlines and tabs were drawn literally, `xml:space` was ignored, `text-anchor` centred on the ink extent rather than the advance width, and a `<desc>` or `<title>` inside `<text>` was rendered as text (#1793). `<text>` is now a list of runs built by walking the element in document order with one cursor: `AB<tspan>CD</tspan>EF` at `x="5"` draws at 5, 51.69 and 102.23, `x` starts a new chunk while `dx` moves the cursor, white space is collapsed per SVG 1.1 10.15 unless `xml:space="preserve"` says otherwise, `text-anchor` shifts a whole chunk once, and only `<tspan>`, `<textPath>` and `<a>` contribute content. **Text geometry shifts**; a `<text>` with no `<tspan>` and no interior white space is unchanged
- `SvgBrush` gains `preserveSpace`, inherited like every other property
- **Fix `stroke-linejoin="miter"` never matching.** The lookup table keyed it `'miter '`, with a trailing space, and a failed lookup is indistinguishable from 'not specified' - so a shape restating the default join inside a `round` or `bevel` group kept the inherited one and its corners stayed rounded. It was invisible wherever no ancestor had overridden the join. The value is also trimmed now, and SVG 2's `miter-clip` and `arcs` fall back to a miter
- **Fix `stroke-width="0"` still painting a hairline.** PDF reads `0 w` as the thinnest line the device can draw, while SVG reads `stroke-width:0` as 'do not paint the stroke', and the stroke block was entered on the colour alone - so an SVG that switches its stroke off this way got an outline no browser draws. Paths and stroked `<text>` now skip the whole block, emitting no colour, dash, cap, join, `w` or `S`. A negative width means the same. An omitted or positive width is byte-identical
- **Fix a malformed `transform` aborting the document.** No argument count was checked: `matrix()` with seven arguments handed `List.filled` a negative length and threw a `RangeError` out of `pdf.save()`, `matrix()` with fewer was zero-padded into a singular matrix that collapsed everything drawn after it, the other five functions indexed their first argument unguarded, and a non-numeric argument threw a `FormatException`. Each function is now checked against its SVG 1.1 7.6 signature and skipped when it does not match, so `translate(10,10) scale()` keeps its translation. `gradientTransform` goes through the same parser. Every currently valid list is unchanged
- **Fix SVG soft masks getting a page-space `/BBox` for a stream drawn in user space**, so an element with `mask="url(#...)"` - or a shape filled by a gradient with `stop-opacity` below 1 - vanished, or kept only a corner, whenever the viewBox extent was larger than the page in points. Both sites handed the mask's Form XObject a rectangle in page points, and the form is evaluated under the SVG user-space transform, so a 1024-unit drawing on A4 was masked to its first 595x842 *user units* and the rest fell into the `/Luminosity` black backdrop at alpha 0. The `/BBox` is now the page box mapped back through the current transform: `[0 0 1024 1024]` where it used to say `[0 0 300 300]`, and it covers a negative or offset viewBox origin. **Every mask and gradient-alpha document changes bytes**
- **Fix `clipPathUnits="objectBoundingBox"` being applied in user units**, which clipped the artwork to about a one-unit sliver and made it disappear with no error. The referenced `<clipPath>`'s `clipPathUnits` was never read; a fractional clip path is now scaled and offset by the bounding box of what it clips, so a 60x40 element at (20, 30) emits `60 0 0 40 20 30 cm`. An empty or zero-area box clips everything away rather than writing `NaN`
- **Fix `clip-rule="evenodd"` being ignored**, so a donut or knockout crop filled its own hole: `clipPath()` was always called with the nonzero rule. Both the attribute and the `style` form now emit `W* n`. A `userSpaceOnUse` clip with no `clip-rule` is byte-identical
- **Fix `style="display:none"` and `style="visibility:hidden"` being ignored, so hidden layers were painted.** Inkscape, Figma and Illustrator all export a hidden layer as `<g style="display:none">`, and the two tests read raw XML attributes while `style` was flattened onto the element later, from `SvgBrush.fromXml` - so the attribute form worked and the style form never did, and a hidden layer was drawn over the visible artwork. `style` is now flattened before the test. The root `<svg>`'s own `display` and `visibility` were never tested at all, because the painter builds the root as a group directly; they are now
- **Fix `SvgParser.convertStyle` throwing `Bad state: No element` on a declaration without a colon.** It called `.first` on the matches of each fragment, so `style="fill:#f00;stroke"`, a vendor-prefixed declaration such as `-inkscape-stuff`, or any leftover of a value that the naive split on `;` had cut in two aborted the whole document from `Document.save()`, naming neither the file nor the declaration. A malformed declaration is now skipped and its neighbours still apply, and the split happens only on a semicolon that is outside quotes and outside parentheses - so a legal `font-family:'A;B'` or `url(data:image/png;base64,...)` survives. Values are trimmed, and 2000 pseudo-random strings parse without an exception
- **Fix a nested `<svg>` element being silently dropped.** `SvgOperation.fromXml` had no `svg` case, so the element fell through to `return null` and the group dropped it: the whole subtree vanished with no exception and no log line, and a document holding only that had no `/Contents` entry at all. A nested `<svg>` now establishes a viewport of its own - `x`, `y`, `width` and `height`, defaulting to the parent viewport - clips to it, and fits its `viewBox` into it. The root `<svg>` is unaffected
- **Fix `<symbol>`'s `viewBox` and `<use>`'s `width` and `height` being ignored.** `SvgSymbol` never read `viewBox` or `preserveAspectRatio` and drew its children in the parent's user space, and `SvgUse` parsed `width` and `height` into dead fields - `paintShape` applied a translation and nothing else. So an icon sprite's 100-unit symbol placed with `<use width="24" height="24">` drew at 100 units and was mostly clipped away, and a symbol with no `viewBox` bled outside its `<use>`. A `<use>` of a `<symbol>` now establishes a viewport, clips to it and fits the symbol's `viewBox` into it; `<use>` of anything else is unchanged
- `preserveAspectRatio` is now honoured - `meet`, `slice`, `none` and all nine alignment keywords - wherever a viewBox is fitted into a viewport. A `<use>` or nested `<svg>` with a zero width or height renders nothing, as the specification asks, and one with no width or height uses the current viewport
- **Fix SVG percentage lengths being divided by 100 instead of resolved against the viewport.** `SvgNumeric` had no viewport to work from, so a percentage became a bare fraction: `<svg width="100%">` laid out as a **1x1pt speck** with its content clipped away, `<rect width="50%">` in a 24-unit viewBox drew half a unit, and `stroke-width="10%"` became a 0.1-unit hairline (#1849). A percentage is now a fraction of the current viewport - of its width for a horizontal length, its height for a vertical one, and of `sqrt((w^2 + h^2) / 2)` for a radius, a stroke width or a dash offset, as SVG 1.1 7.10 requires. A percentage root size is a fraction of the box the `SvgImage` is given, falling back to the viewBox size when that box is unbounded. **Gradient coordinates and stop offsets still read a percentage as a fraction**, which is what they mean, and absolute units are unchanged
- `SvgParser` gains `rootWidth` and `rootHeight`, the root size attributes as written; `width` and `height` are now null when the attribute is a percentage
- **Fix a cyclic SVG `<use>` killing the isolate with a `StackOverflowError`.** `<g id="a"><use href="#a"/></g>` resolved its reference and built the target again with no record of what was already being expanded, and because SVG children are built lazily the recursion ran during paint - so the overflow came out of `pdf.save()` as an `Error`, which a `try`/`catch` around the build usually misses. A `<use>` that points at an ancestor or at an id already being expanded now paints nothing, which is what SVG 1.1 asks for, and the content around it still draws. The href is also read properly: `href=""`, `href="#"` and `href="other.svg#a"` used to take `substring(1)` of whatever was there. Acyclic graphs are unchanged
- **Fix an SVG `<image>` that is not 32-bit RGBA aborting `save()`.** `SvgImg.fromXml` handed package:image's own storage buffer to the raw `PdfImage` factory, which needs tightly packed 8-bit RGBA - and package:image keeps 1 byte a pixel for grayscale and palette images, 3 for RGB and JPEG, and packed bits for a 1-bit palette. So an SVG embedding anything but an RGBA PNG threw `RangeError (length): Not in inclusive range 0..N` out of the whole document, and an equal-length buffer with a different layout came out with permuted colours (#1530, #1807). The payload now goes through `PdfImage.file`, which sends a JPEG to `/DCTDecode` and converts everything else. **A JPEG data URI is now embedded as JPEG rather than re-encoded, and its EXIF orientation is honoured, so SVG output bytes change**
- **Fix an SVG `<image>` with an undecodable payload aborting the document.** The data URI branch was unguarded: `base64.decode` throws on malformed input and `im.decodeImage` throws on empty or truncated data before it can return null, so a nested `image/svg+xml` payload, a truncated raster or a bad base64 string killed the whole document with `Null check operator used on a null value` or a `RangeError` (#1508). An unusable `<image>` now costs that one element, as `SvgImg.paintShape` already allowed for, and says why in a verbose debug build
- **Fix a data URI with extra header parameters being dropped.** Only the text right after the first `;` was examined, so `data:image/png;charset=utf-8;base64,...` was ignored and the image silently disappeared. Any header ending in `;base64` is now read, **so an SVG that was missing an image may now draw one**
- `PdfImage`'s raw factory asserts that its buffer is long enough for the width and height it was given, instead of overrunning it

## 3.17.0

- **Fix polygon and ink annotation coordinates landing below the page.** The `Polygon` and `InkList` widgets paint each point at `(x, box.height - y)`, and the annotation builders handed the raw points to the object layer, which flipped them a second time - against its own `/Rect`, on coordinates already in page space - so every vertex came out at about `-pageY`, outside the `/MediaBox`, with a `/Rect` that did not cover the shape either. The page still painted, so nothing looked wrong; the annotation was simply dead. The flip now happens once, in the widget layer, before the point is mapped to page space, and `/Rect` is derived from the result. **`PdfAnnotPolygon` and `PdfAnnotInk` points are in default user space**: one built directly is emitted verbatim
- **Fix a multi-stroke `InkAnnotation` emitting every point in every stroke.** The accumulator was `List.filled(n, <num>[])`, which stores the same growable list in every slot, so all the strokes were appended to one list and `/InkList` came out as N references to it: a captured signature was drawn N times, with spurious lines joining the strokes. Each stroke now gets its own array, so a two-stroke annotation emits two sub-arrays rather than two copies of everything
- **Fix `PolygonAnnotation` emitting `/Subtype /PolyLine`.** The two names were swapped - ISO 32000-1 12.5.6.9 maps a closed shape to `/Polygon` - and `AnnotationPolygon` had no `closed` to pass, so both widgets wrote `/PolyLine`: a polygon was drawn open, missing its last edge, and never filled, which made `interiorColor` inert. `PolygonAnnotation` is now `/Polygon` and `PolyLineAnnotation` is `/PolyLine`. **`PdfAnnotPolygon.closed` keeps its name and reverses its meaning**, so a caller who passed `closed: false` to get `/Polygon` now gets `/PolyLine`; `AnnotationPolygon` gains an optional `closed`
- **Fix a `PdfColor`'s alpha being discarded by every fill and stroke**, so a translucent colour painted fully opaque and `PdfColor.fromInt(0x00000000)` painted solid black (#1643). PDF carries constant alpha in an `/ExtGState` `/ca` or `/CA`, never in the colour operators, and `setFillColor` and `setStrokeColor` wrote only `rg`, `k`, `RG` or `K` - so the alpha of a colour from `fromInt`, from `#RRGGBBAA` hex or from the fourth constructor argument never reached the file, and all 79 widget-layer call sites inherited the loss. A colour's alpha now puts a constant alpha in force, scoped by the existing `q`/`Q` stack, and `Opacity` composes with it: `Opacity(0.5)` around a 50%-alpha container gives 0.25. **A fully opaque document emits no `/ExtGState` and is byte-identical.** `PdfColor.transparent` in SVG, which is alpha 0, now paints nothing
- `PdfDocument` and `Document` take `colorAlpha: false` to go back to ignoring a colour's alpha - PDF/A-1 forbids transparency
- `Opacity` inside `Opacity` now multiplies, where the inner one used to replace the outer
- **Fix `PdfColor.isDark` and `isLight` being each other's opposite**: `PdfColors.white.isDark` was true and `PdfColors.black.isLight` was true. The luminance test is Flutter's `estimateBrightnessForColor`, whose true branch means *light*, and it was returned from `isDark`; `isLight` was defined as its negation, so both were wrong. Code that followed the doc comments - `color.isDark ? white : black` - drew white on white. The body now belongs to `isLight` and `isDark` is its negation; the formula and the 0.15 threshold are untouched, so the crossover stays at a relative luminance of about 0.3373. **Any code that compensated for the inversion has to drop the compensation**; the two places in this repository that did - the pie-chart legend and the demo invoice - are flipped in the same change, and the pie chart's output is byte-identical
- Document the straight-alpha contract on `PdfImage.new`, `PdfRasterBase.new` and `RawImage`: the colour bytes and the `/SMask` are straight, not premultiplied, alpha, and the width and height describe the buffer rather than how it is displayed
- **Fix an `ImageProvider` pinning a whole `PdfDocument` per layout width.** The cache was an unbounded map on the provider itself, keyed only by the pixel width, and a `PdfImage` holds the `PdfDocument` it was built for - which holds every page, font and content stream in it. A long-lived provider kept one image per distinct width for ever, so a service reusing one leaked roughly a finished document per width: five documents through one provider left all five reachable after garbage collection, and now leave none. The cache is now an `Expando` keyed by the document, so it dies with it. Deduplication inside one document is unchanged
- **Fix an `ImageProxy` reused in a second document writing a reference to an unrelated object.** `resolve` did notice that the image belonged to another document, and answered it by calling `buildImage` again - which hands back the same foreign image - so document A's object number landed in document B's `/XObject` dictionary and the viewer drew nothing, with no error at all. **`ImageProxy` now throws a `PdfException` instead of producing a corrupt file**; `MemoryImage`, `ImageImage` and `RawImage` build one image per document and are unaffected. A provider that ignores the context it is given now also trips a debug assertion
- `ImageProvider` gains `debugCacheLength(document)`, for tests
- **Fix every image provider dropping the orientation it was asked for.** `ImageProvider` keeps the orientation and swaps the width and height it reports, but no `buildImage` forwarded it: `MemoryImage`, `ImageImage` and `RawImage` built their `PdfImage` without it across six call sites, and `PdfImage.file` dropped it for JPEG bytes by delegating to `PdfImage.jpeg` without the argument. So `pw.Image(pw.MemoryImage(bytes, orientation: rightTop))` drew unrotated and, because the box had been sized for the rotated image, shrunk inside it - `printing`'s `imageFromAssetBundle` and `networkImage` inherited this. The resolved image's orientation, width and height now match the provider's, on the resample path too. `PdfImage.file`'s `orientation` becomes nullable, where null means use what the file itself declares
- On the resample path a source EXIF orientation is left where `im.decodeImage` already baked it, so a rotated photograph is not turned twice; an explicit orientation given for a JPEG that has its own EXIF therefore applies to the unresampled image only
- **Treat EXIF as the untrusted input it is.** `_readTagValue` read the value count straight off the wire and used it as the allocation size and the loop bound for every typed list, with no check against the file length, and the value offset was an unchecked uint32 - so a 59-byte JPEG could ask for 32 GiB (an actual `OutOfMemoryError`) or read half a megabyte past its own end. A declared count of 0 underflowed the ASCII length to -1, a single DOUBLE read eight bytes from the four-byte inline value field, the IFD entry count was unbounded, and a segment length of 0 or 1 moved the cursor backwards and spun for ever. The declared extent must now fit in the buffer before anything is allocated, inline against out-of-line is decided on the byte count as the format requires, the marker walk and the IFD walk stop at the end of the buffer, and a file with no JPEG in it throws a `PdfException` rather than a bare `String`. Well-formed EXIF is unchanged
- **Fix `PdfJpegInfo.orientation` throwing `NoSuchMethodError` on a malformed Orientation tag.** It computed `tags[Orientation] - 1` on a `dynamic` whose shape is whatever the file's type and count bytes say, so an Orientation stored as ASCII, as a float, or with a count above 1 threw `Class 'Uint16List' has no instance method '-'` out of `PdfImage.jpeg` and aborted the whole document. Every accessor is now total: `orientation` coerces an int, the first element of a list, an ASCII digit string or an integral double, bounds-checks 1..8 and falls back to `topLeft`, and `exifVersion`, `flashpixVersion`, `x`/`yResolution` and `pixelX`/`YDimension` fall back to null, the width or the height instead of throwing
- **Fix Adobe CMYK JPEGs with an APP14 transform of 0 being embedded without the inverting `/Decode` array**, so they printed as colour negatives, while a four-component JPEG with no Adobe marker was inverted although it should not have been (#1908). One field meant both 'is there a marker' and 'what does its transform byte say', and the transform byte is only present when the segment is long enough. Marker presence is now recorded separately and `isCMYKInverted` is `isCMYK && hasAdobeMarker`; an Adobe segment too short to hold a transform byte is still an Adobe file
- `PdfJpegInfo` gains `hasAdobeMarker` and `adobeColorTransform`; `PdfImage.jpeg` gains an optional `cmykInverted` override for the rare four-component file whose marker does not match how it is stored

## 3.16.0

- **Fix `MultiPage` silently ignoring `PageTheme.clip`.** `Page.paint` emits the printable-box clip when the theme asks for it, but `MultiPage` overrides `postProcess` wholesale and paints every layer itself, so it never called `Page.paint` and the flag was dropped for every page it wrote: over-wide content bled past the margins and over the header and footer, with no error or warning, and printers cropped the bleed. The rect and its two canvas calls move into `Page.printableBox`, `Page.pushPageClip` and `Page.popPageClip`, and `MultiPage` wraps each page's background, header, body, footer and foreground in one balanced pair. Both now emit the same rectangle - `50 50 495.27559 741.88976 re W n` on A4 with a 50pt margin, `40 30 535.27559 801.88976 re W n` in landscape with `LTRB(10, 20, 30, 40)`. **`clip: true` now crops `MultiPage` content that used to escape.** With `clip: false` the output is byte-identical
- `Page` gains the protected `printableBox`, `pushPageClip` and `popPageClip`
- **Fix `PageTheme.copyWith` re-rotating the margins of a rotated theme on every call.** It fed the derived `margin` getter back into the constructor, which stores it raw - and the getter is where the edges are rotated when the orientation is forced and where a null margin falls back to the page format's. So deriving per-page themes from an A4-landscape theme cycled the four margins one quarter turn per call, moving and resizing the content box: `LTRB(10, 20, 30, 40)` read `(40, 10, 20, 30)` on the base theme and `(30, 40, 10, 20)` one `copyWith` later. An implicit margin was also frozen into an explicit one, so `copyWith(pageFormat: ...)` kept the old format's margins. `copyWith` now copies the raw field, and its `margin` parameter widens from `EdgeInsets?` to `EdgeInsetsGeometry?` so a directional margin can be passed back - source-compatible
- **Fix a `PageTheme` with an `EdgeInsetsDirectional` margin and no `textDirection` throwing from its `margin` getter.** The directional margin was resolved before the rotation test, although only the rotating branch needs physical edges, and `EdgeInsetsDirectional.resolve` asserts on a null direction. It now resolves only where it must, falling back to `TextDirection.ltr` as `Directionality.of` does; `Page.resolvedMargin` does the same
- **Fix `AspectRatio` without a child throwing during layout.** The sanity check on the child's box sat outside the null guard, so an `AspectRatio` used as a spacer threw `Null check operator used on a null value` wherever asserts are on - every test run and every debug build - while release builds produced the right document. Release output is unchanged
- **Fix `ClipRRect` exchanging its two radii.** `PdfGraphics.drawRRect` takes the vertical radius fifth and the horizontal one sixth, and both `ClipRRect.paint` and `ClipRRect.debugPaint` passed them the other way round, so `horizontalRadius: 40, verticalRadius: 5` clipped corners 5 wide and 40 tall and disagreed with a matching `BoxDecoration`. **A caller who compensated by swapping the two will see their corners transposed.** Equal radii, which is how the repo's own page uses it, are byte-identical
- **Fix a default `BoxShadow` being invisible.** `PdfRasterBase.shadowRect` allocated a bitmap only `spreadRadius` larger than the box and filled it edge to edge, so with the default `spreadRadius` of 0 the Gaussian blur had nowhere to bleed and handed back the same opaque rectangle: `BoxShadow(blurRadius: 8)` painted a hard box under the box, with nothing but a hairline showing. Rendered at 72 dpi, a 100x50 box with an 8pt blur had 151 non-white pixels outside it, all one shade of grey; it now has 5997 in 154 shades. `spreadRadius` also only padded the bitmap instead of inflating the shape, so the shadow's core was never larger than the box - it now means what it means in Flutter, and `shadowRect(100, 50, 10, 0, black)` has a core of exactly 120x70. `shadowEllipse` had the same missing margin and used a circle of the box's width as its shape; it now has two radii. The new `PdfRasterBase.shadowMargin` is how far the bitmap reaches past the box, and the three draw sites offset by it and pass the bitmap's own size, so one pixel is still one point. **Both helpers keep their signatures but return larger bitmaps**
- **Fix `Transform.rotateBox` laying its child out against the unrotated constraints.** The child measured in the parent's frame although it is painted rotated, and the bounding box of the rotated corners was then taken with no clamp - so a quarter-turned child neither filled the space it was given nor stayed inside it. On A4, `Column[40, Expanded(Align(rotateBox(pi/2, Image(400x300)))), 40]` gave a box 361.42pt wide in the 481.89pt available, and the same tree with a 300x400 image gave 642.52pt and painted off the page; 10 of 13 angles overflowed a `BoxConstraints(maxWidth: 200, maxHeight: 300)`. A quarter turn now measures against the flipped constraints, as Flutter's `RenderRotatedBox` does, and any other angle that overflows is measured again in a frame scaled down by however much it overflowed. `angle: 0` and `angle: pi` are unchanged, and `unconstrained: true` still produces an unclamped box (#1523)
- `BoxConstraints` gains `flipped`, the same constraints with width and height exchanged
- **Fix a rotated vertical chart axis reserving the label's width where it needs its height.** The vertical branch of `FixedAxis.layout` was copied from the horizontal one without swapping the axis: `crossAxisPosition` and `_marginEnd` are distances *along* the axis, so a vertical axis needs the label's height there, and it used `PdfPoint.x`. Rotated y-axis labels spilled over the x-axis labels, and because the two axes are coupled - each one's cross position is the other's axis position - a wrong vertical margin took the plot's height with it. Every cartesian chart also gains the space the top label was over-reserving: 33.36pt becomes 17.34pt for a 30pt label at angle 0. The horizontal branch is unchanged
- **Fix a `Table` laying its columns out left to right on an rtl page.** `Table.layout` accumulated cell origins from `x = 0` in source order and never asked for the direction, so the first cell of every `TableRow` stayed on the left while `Row`, `Wrap`, `Stack` and `GridView` all mirrored - an Arabic or Hebrew report read backwards, and `TableHelper`'s `headerDirection` and `tableDirection` reached only the text inside each cell, never the column order (#1473, #1526). Columns now follow the resolved text direction, and the inside border rules move with them. `_widths` stays in logical order, so `columnWidths[i]` still addresses the i-th child. LTR output is byte-identical
- `Table` gains an optional `textDirection`. **An rtl caller who reversed their own rows as a workaround will now see them reversed twice**: pass `textDirection: TextDirection.ltr` to keep that table as it was
- **Fix an RTL `GridView` shifting every child by about a cell and drawing columns outside the grid.** The children were laid out left to right and then mirrored with a second expression that was not the mirror of the first: the vertical branch was correct only for `crossAxisCount: 3` with no spacing, no padding and full-cell children, and the horizontal branch right-aligned in the band, losing the centring term and twice the left padding. With `crossAxisCount: 1` the child landed 400pt right of where it belongs, off a 200pt page; four or more columns gave trailing children a negative x. The rtl position is now derived by mirroring the ltr one about the padded content band, so the two agree for every column count, spacing and padding. LTR layout is unchanged, as is the three-column full-cell case under RTL
- **Fix the deprecated `Table.fromTextArray` overwriting the caller's `headerCount` with 1.** The argument was forwarded as `headerCount: headerCount = 1`, which in Dart assigns 1 to the parameter and evaluates to 1, so `TableHelper.fromTextArray` always received 1 however the caller was written. `headerCount: 0` therefore header-styled the first data row, repeated it on every page and shifted the zebra striping by a row; 2 or more silently lost the extra header rows. Calls that omit `headerCount` are unchanged, since the default is still 1
- **Fix `AlignmentDirectional`'s top and bottom constants being vertically inverted.** This package puts y up - `Alignment.topLeft` is `(-1, 1)` and `inscribe` treats `y = 1` as the top - but `AlignmentDirectional` was copied from Flutter with its y-down constants, and `resolve` mirrors x only. So `AlignmentDirectional.topStart` placed its child at the *bottom* of the box, `bottomStart` at the top, and a `topCenter` to `bottomCenter` gradient ran backwards. The six vertical constants are now y-up, so each one resolves to the physical constant of the same name - `topStart` to `Alignment.topLeft` under ltr and `Alignment.topRight` under rtl. **A document that uses these constants and compensated for the inversion will move.** `centerStart`, `center` and `centerEnd` have `y == 0` and do not move
- **Fix `Alignment.toString()` naming the opposite corner**: the label table was the y-down one, so `Alignment.topLeft` printed `Alignment.bottomLeft`. Debug output only

## 3.15.0

- **Fix a single-colour gradient painting its whole bounding box and an empty one blanking the page.** `BoxDecoration.paint` builds the decoration path and hands it to `Gradient.paint` to consume. With one colour both `LinearGradient` and `RadialGradient` filled the path and then fell through to `saveContext()..clipPath()`, so `W n` was emitted with no current path: a clip built from nothing clips nothing and the shading painted its whole bounding box, drawing a circle-shaped `Container` as a square - confirmed at 72 dpi, where every corner came out the gradient colour. With no colours at all they returned leaving the path open, running the next `q`, `Q` or `cm` into a path-construction run, and because nothing had set the page's altered flag a page with only that on it was written with no `/Contents`, losing everything else drawn on it. One colour now fills and returns without creating a shading object; no colours end the path. Gradients of two or more colours emit byte-identical content streams
- **Fix gradients writing `/Order 3` over the two samples they interpolate.** `PdfFunction.order` was written as `/Order`, the interpolation order, and used as bytes per sample to derive `/Size`, and `fromColors` passed `order: 3` to mean three colour components - so every gradient claimed cubic interpolation, which needs at least four samples, and `PdfFunction(order: 3)` emitted a `/Size` three times too small. `PdfStitchingFunction` also hard-coded `/Order 3` into a `FunctionType 3` dictionary, where `/Order` has no meaning. `/Size` is now derived from the output count and `bitsPerSample`, and `/Order` is written only when it is not the default 1. `/Size`, `/Domain`, `/Range`, `/BitsPerSample` and the stream bytes are unchanged for every gradient and for the soft-mask transfer function; only `/Order` disappears
- `PdfFunction.order` now means what `/Order` means in the PDF specification - the interpolation order, 1 or 3, default 1 - rather than components per sample. Anything else throws a `PdfException`, as does an order of 3 with fewer than four samples
- `PdfGraphics` gains `endPath()`, which ends a path without painting it
- **Fix `bezierArc` losing the end point when the radii are too small for the chord.** SVG F.6.6 scales the radii up until the ellipse reaches both points, and F.6.5 then puts the centre exactly on the chord's perpendicular bisector - at distance zero, because the corrected ellipse passes through both. One variable held the ratio and then the centre factor in turn, and that branch re-assigned the ratio without converting it, so it stayed 1.0 and the centre landed a whole radius away: `bezierArc(100, 400, 10, 10, 200, 400, sweep: true)` ended at (185.35534, 414.64466) instead of (200, 400), and a half circle - where the ratio rounds to an ULP over 1 - missed its end point by the radius, 20.7pt on a radius-50 circle. Pie slices and donuts of 180 degrees or more were drawn off their own circle. Arcs whose radii already span the chord are byte-identical
- **Fix `CrossAxisAlignment.stretch` writing `Infinity` into the content stream.** Both stretch branches tightened the cross axis to the incoming maximum without checking it was finite, and a `Flex` hands a non-flex child an unbounded cross axis by design, so a stretched `Flex` nested inside one running the other way emitted `0 0 Infinity 20 re` - which viewers drop, losing the drawing - or a page with no `/Contents` at all. It now throws a `PdfException` naming `stretch` and the unbounded axis where asserts are on, and falls back to the loose constraints the child would otherwise have had in release. A bounded cross axis is unchanged
- **Fix a `Stack` on an unbounded axis emitting `Infinity` and `NaN`.** A `Stack` inside a `Row`, a `ListView` or any other unbounded parent took `constraints.biggest` verbatim on three paths - no children, `StackFit.expand` and the all-`Positioned` case - so the overflow clip came out as `0 0 Infinity 728.5 re W n`, which a viewer drops along with the whole stack, and `Alignment.inscribe` subtracted two infinities and handed every child a `NaN` offset. An unbounded axis now falls back to the minimum constraint, `StackFit.expand` tightens only the bounded axes, and a debug-only message names the axis
- **Fix a progress indicator with an unbounded width.** `LinearProgressIndicator` used `minWidth: double.infinity` as an 'as wide as possible' sentinel, which `BoxConstraints.enforce` keeps when the incoming `maxWidth` is unbounded - what a non-flex child of a `Row` is given - so the stream carried `Infinity 4.936 Infinity 4 re`; `CircularProgressIndicator` took `constraints.biggest` and its infinite radius threw `Unsupported operation: Infinity or NaN toInt`. Both now throw a `PdfException` naming the widget, whether asserts are on or off, and both take new optional `fallbackWidth` and `fallbackHeight` sizes for an axis the parent leaves unbounded. A bounded parent is unchanged
- **Fix a `TableRow` with an empty `children` list and a decoration painting at `y = Infinity`.** Both decoration phases seeded the band as `y = infinity, h = 0` and lowered it only inside the children loop, so a blank separator row with a background colour wrote `0 Infinity <w> 0 re` and poppler dropped everything drawn after it. Such a row now gets the zero-height band layout already gave it; rows with children are unchanged
- **Fix a `Table` whose columns all measure zero writing `NaN` widths.** The proportional scaling divided by the sum of the intrinsic widths, which is `0.0/0.0` when every column measures nothing - a spacer table of empty `SizedBox`es, or all `FixedColumnWidth(0)` - so `NaN` reached the widths, the table box, every cell box and `drawRect`, and release wrote `q 0 0 NaN 0 re W n`. With `TableWidth.max` the available width is now shared evenly instead; `TableWidth.min` and the flex path are unchanged, as is every table whose columns measure something
- **Fix an overflowing `Table` squeezing a column below the width of one word**, so the cell hard-split it: 'ATLANTICA' rendered as ATLANTI then CA. The columns were rescaled by one factor with no per-column floor. A column now keeps at least what its longest unbreakable piece needs and the remaining space is shared in proportion to how much more each column wanted, as CSS automatic table layout does; if not even the minimums fit they are scaled down together. Widths still sum exactly to the table's width, and a table whose columns already fit is unchanged
- `ColumnLayout` gains an optional `minWidth`, and a new `MinContentWidth` marker asks a subtree to lay itself out as narrow as it can go: `Text` and `RichText` honour it by taking the width of their widest unbreakable piece, and any widget in between contributes its own padding because it is an ordinary layout pass
- **`MultiPage` output is no longer quadratic in a `Table`'s row count.** The column measure pass ran again for every page, and `MultiPage` also laid each child out with an unbounded height first, only to learn how tall it would be - so a `Table` laid out all its remaining rows on every page. The widths are memoized against the width, theme and direction they were measured for, and a spanning widget can now opt into being laid out against the height that is actually left. 2000 rows x 5 columns went from 15.9s to 0.34s here, and the measure pass runs 2000 times instead of 16000
- `SpanningWidget` gains a `reportsCompletion` getter, false by default; `Table` sets it. `Table.hasMoreWidgets` is an exact answer after any layout
- **Fix a chart axis of one value, or of values that are all equal, writing `NaN`.** `FixedAxis.toChart` divided by the axis range, which is exactly zero in both cases, so `FixedAxis.fromStrings(['Phone'])` aborted `save()` with an assertion or wrote `NaN` tokens that made viewers drop the chart. A lone value now sits in the middle of its band; an axis with two or more distinct values is bit-identical to before
- **Fix a chart axis built from an empty value list losing the whole document** - `Bad state: No element` with asserts on, `Null check operator used on a null value` in release. `FixedAxis<int>([])` and `FixedAxis.fromStrings([])` construct, lay out and render an empty plot area; an unsorted list is still rejected
- **Fix a single-slice pie or donut rendering blank for about one value in twenty** - 87.5, 75, 150, 350 among them. The bearings were accumulated, so the two roundings could leave the sweep one ULP short of a full turn, and the exact full-circle test then took the wedge branch, whose two endpoints coincide: the path enclosed nothing, with no error and no log. Each boundary now comes from the running sum, so the last one is exactly the start plus a full turn, and the full-circle test has a tolerance
- **Fix an all-zero pie chart losing the whole document** with `Unsupported operation: Infinity or NaN toInt`. Dividing by a zero total gave every slice `NaN` bearings, which slipped past every guard in the arc. A total of zero, a negative total or a non-finite one is now 'no data': the slices are empty, nothing is stroked or filled for them, and their legends are still spread around the circle. Negative and non-finite values are ignored when summing
- **Fix a `fontSize` or `textScaleFactor` of 0 writing a `NaN` token.** `letterSpacing` is divided by the effective size to convert it to font units, and at size 0 that is `0.0/0.0`: the `NaN` reached the advance, the offset and then a `Td` coordinate - an `AssertionError` out of `save()` with asserts on, a bare `NaN` where a number belongs in release. A zero-size paragraph now lays out to a finite empty box
- **No number a PDF reader cannot parse is ever written.** A non-finite value went through `toStringAsFixed`, which returns `NaN` or `Infinity`, and anything from 1e21 up came out in exponent notation - ISO 32000-1 7.3.3 has syntax for none of them, so the reader dropped the whole operator or dictionary entry. Asserts were the only guard and release builds strip them. A non-finite value now writes `0`, and a large one writes fixed notation clamped to 3.403e38, so every number matches `-?[0-9]+(\.[0-9]+)?`. Finite values below 1e21 are unchanged, and a `PdfDocument(verbose: true)` reports each substitution instead of the assert that used to throw
- **Fix a form XObject's resource key not being a name object.** `PdfXObject.name` was the only resource name in the package without a leading solidus, so the `/XObject` dictionary key came out as a bare `X4` - which poppler rejects, dropping the page - while the two form subclasses overrode it with a slash and the `Do` operand then came out as `//X4`. A resource name always carries the solidus now, and the key and the operand are the same string
- **Fix an SVG or widget form XObject rendering blank.** Both painted onto a page of a second, discarded document, so `PdfGraphics` registered every font, shader, pattern and graphic state on that page while only the bytes reached the form: the form had no `/Resources` at all and its stream named objects nobody ever wrote. They now paint into the form itself, against the document that owns it, so a gradient, an opacity and a font all land in the form's own resources. `WidgetPdfFormXObject` takes an optional `page` for widgets that read `Context.page`
- **Fix a form XObject whose `/BBox` does not start at the origin drawing squashed and offset.** `drawXObject` read the third and fourth `/BBox` entries as the width and height, but `/BBox` is `[llx lly urx ury]`: a box of `[10 20 110 70]` asked to draw 100x50 emitted a scale of 0.909 by 0.714 and no translation at all, where scale 1 and a translation of (-10, -20) is right. A reversed box is normalised, and a box with no area draws nothing instead of putting `Infinity` in the stream. A zero-origin box is unchanged
- **Fix `PdfSoftMask` and `PdfAnnotBase.appearance` writing `/BBox` as `[left bottom width height]`.** A form XObject `/BBox` is `[llx lly urx ury]`, so for a non-zero origin the upper-right corner was short by the origin and the rectangle could invert: a mask was clipped to the wrong rectangle, with alpha 0 outside it, and an appearance was clipped and then stretched to fill `/Rect`. Both go through one `PdfArray.fromRect` helper now, with `/Rect` and the shading `/BBox`, so the writers cannot drift again. Zero-origin output is unchanged, which covers every caller in this package
- **Fix `setFillColor`, `setStrokeColor` and `setColor` throwing on the null colour their signatures accept.** `null is PdfColorCmyk` is false, so null fell into the RGB branch and was dereferenced there. A null colour now leaves the current colour alone and writes nothing
- **Fix an `Image` with an explicit `width` or `height` overflowing its slot.** The size was used verbatim instead of being passed through the incoming constraints, so `Expanded(child: Image(img, width: 400))` tripped `childSize <= maxChildExtent` in debug and silently overlapped its neighbours in release, and inside a 100x100 container an image declared 400 wide measured 200x100. An explicit size is a preferred size the parent may override now; the fit's aspect ratio is kept, and the box never exceeds `maxWidth` or `maxHeight`
- **Fix a zero-sized image slot writing `NaN` operands.** The draw divided by a source rectangle that `applyBoxFit` returns zero-sized for a degenerate destination; `Container(width: 0, child: Image(...))` threw `'!value.isNaN'` out of `save()` with asserts on and wrote the token in release. There is nothing to draw, so nothing is drawn

## 3.14.0

- **Fix a font whose cmap has a format 0 subtable mapping every character to the wrong glyph.** The glyph array was read two bytes early, so 'ABC abc' rendered as '?@A _`a' and U+0041 came back as glyph 63, with no error and no fallback
- **Fix a font carrying a Macintosh or symbol cmap subtable drawing the wrong glyphs.** Every recognised subtable was merged into one map, in record order, but a Macintosh subtable is keyed by Mac Roman bytes and a symbol subtable by 0xF000-offset codes while every consumer reads the map as Unicode. Only the best subtable is used now, and its keys are translated to Unicode. With `hacen-tunisia.ttf`, `Text('ª')` drew the trademark glyph and a document holding both threw 'Missing glyph for character'
- A symbol font's glyphs are reachable by their low byte as well as their 0xF0xx code, so `drawString('A')` finds one
- **Fix cmap format 4 ignoring a segment's `idDelta` for a glyph-id-array lookup**, which rendered that whole range with its glyphs shifted
- **Fix glyph 0 being recorded as coverage.** Format 4 defines it as 'not covered', so a character in a hole looked supported, `TextStyle.fontFallback` was skipped, and the reader drew .notdef - an empty box. Such runes now reach the fallback font
- A malformed or truncated cmap subtable is skipped rather than throwing a `RangeError` in release or an `AssertionError` in debug
- **Fix a blank implemented as an empty glyph drawing the next glyph in the font.** `readGlyph` never consulted the glyph's size, and an empty glyph shares its offset with the one after it, so `drawString('A B')` rendered 'A¡B' with open-sans and `Text('a​b')` drew a box over the 'b'. Every empty glyph in every bundled font was affected - 17 in open-sans, 19 in roboto, 20 in noto-sans - and the subsetter embedded those wrong outlines
- A glyph's bytes are now clamped to what the font's `loca` table says the glyph occupies, so a malformed table cannot hand back its neighbour's outline
- **Fix subsetting aborting with 'Null check operator used on a null value' for a TrueType font that has no OS/2 table** - AppleGothic, some CJK and icon fonts. The emitted table directory came from a hard-coded ten-entry list while the table copy skipped what the source font did not have. It is now derived from the tables that are actually present, so the header, the records and the payloads agree by construction
- A font with no `post` table is given a synthesised one, and a font with no `hmtx`, `head`, `maxp` or `hhea` fails with an exception naming the font and the table
- **Fix every embedded subset dropping the hinting programs its glyph outlines call.** `cvt `, `fpgm`, `prep` and `gasp` are copied now, so a subset is no longer structurally invalid - its glyph programs called missing functions and indexed an absent control-value table, which shifted outlines on FreeType-based print paths and could stop a strict RIP loading them. Subsets grow a few KB
- Fix the emitted sfnt binary-search fields, which were 256/2/96 where the spec requires 128/3/32, and the table directory, whose records were in layout order rather than the required ascending tag order
- **Fix a font passed as a sliced `ByteData` being misparsed.** Every accessor was view-relative but the reach-throughs to the backing buffer were absolute, so `Font.ttf` over a view threw `FormatException: Missing extension byte` decoding the table tags, or silently parsed a shifted window. All of them are view-aware now, and `TtfParser.fontData` is a new getter returning exactly the view
- **Fix a partial font view embedding the whole backing buffer** while `/Length1` described only the view - 1,093,112 bytes of stream for a `/Length1` of 93,112. A view now embeds byte-for-byte what the whole buffer would
- **Fix copy, in-viewer search and text extraction returning the wrong characters for emoji and CJK ext-B.** The `ToUnicode` CMap wrote each destination as the code point padded to four hex digits, so anything above U+FFFF came out as five - U+1F100 as `<1F100>`, which a reader decodes as U+1F10 followed by a NUL. Destinations are UTF-16BE code units now, so U+1F100 is `<D83CDD00>`. The glyphs always rendered, so nothing looked wrong
- The `ToUnicode` CMap is emitted in sections of at most 100 entries, which is the limit the format sets; it used to be one section for the whole font
- **Fix the standard-14 fonts drawing an en dash, an em dash, a curly quote, a bullet, an ellipsis, a euro or a trademark as a crossed box.** Simple fonts declare `/WinAnsiEncoding` but were addressed as Latin-1. The two encodings agree everywhere but 0x80-0x9F, where WinAnsi holds 27 typographic glyphs and Latin-1 holds the C1 controls, so all 27 were reported unsupported. They render now, and `/Widths` is indexed by WinAnsi code as the declared encoding requires
- **Fix `simpleTrueTypeFonts: true` throwing `ArgumentError: Invalid argument (string): Contains invalid characters` out of `save()`** for the same 27 characters, since the simple TrueType path shares the encoder. Its `/Widths` measured every code in 0x80-0x9F as a C1 control, so all 32 came out zero
- `PdfFont.isRuneSupported` is now false for U+0080-U+009F, which `/WinAnsiEncoding` has no glyph for, and true for the 27 runes it does hold. A rune the encoding cannot express throws `PdfException` naming it, where a simple font used to throw `ArgumentError`; with `simpleTrueTypeFonts: true` such a rune now falls back to `TextStyle.fontFallback` or a placeholder instead of failing the document
- **Fix invisible formatting characters being drawn.** A soft hyphen, a zero-width space, a joiner, a bidi mark or a variation selector after an emoji was laid out as ordinary text: with no font covering it the layout painted a crossed-box placeholder, and with one - open-sans has a glyph for U+00AD - it drew a real hyphen. Every code point with the Unicode `Default_Ignorable_Code_Point` property is now dropped, after the shaping and the bidi reordering that need them, so nothing is measured, drawn or written to `ToUnicode` for one
- **Fix a document written with CR or CRLF line endings running every line together**, with a placeholder box at each break: only U+000A terminated a line. `\r\n`, `\r` and `\n` are each one line break now
- **Fix a non-breaking space breaking a line.** U+00A0, U+2007 and U+202F are the documented way to hold two words together, and Dart's `\s` - the default line splitter - matched all three, so a line broke at exactly the character the author used to stop it. They are part of the drawn run now, with their own advance; U+FEFF, the fourth, is dropped as a default ignorable. Documents relying on the old behaviour re-flow
- **Fix every break measuring as a U+0020.** The gap after a word was measured once from a literal space and charged for whatever the separator really was, so an em space, an ideographic space or a tab advanced by a quarter of an em. `RichText('A\u2003B')` in open-sans at 20pt is 45.6pt wide, not 30.8, and kana + U+3000 + kana in genyomintw is 60.0, not 44.9. A separator the font has no glyph for - no font maps U+0009 - still advances by a space
- **Fix a hyphenated word being cut anywhere but at a hyphen.** `'Hello-World-this-should-break'` fell to a width search with no notion of where a break belongs, so it was cut mid-syllable. A line may now end after a hyphen - not before a digit, so `'3-4'` stays whole, and not at a leading sign - and only falls back to the width search when the word offers nothing
- **Fix a soft hyphen being drawn as a real hyphen and never breaking a line.** U+00AD is invisible until it is used: `'Bundes<SHY>verfassungs<SHY>gericht'` draws as `Bundesverfassungsgericht` and measures the same, and when it has to wrap it breaks at a soft hyphen and puts a visible hyphen at the end of that line
- **Fix U+200B giving no break opportunity at all**, which is the only way to wrap CJK text without a `lineSplitter`. It breaks now and is never drawn. U+2060 takes the following opportunity away, and U+2011 never breaks
- **Fix `save()` aborting with `RangeError (length): Not in inclusive range 0..7: 8` on Arabic** where one of the hamza carriers آأؤإئ is followed by a haraka - 40 of the 45 pairs. The bug is in package:bidi's normalizer, which this package called unguarded on the path every RTL span takes, with no runtime way to opt out. The reordering now falls back to shaping the text without it, which renders differently but stays Arabic
- **Fix an embedded Latin run landing on the wrong lines, in the wrong order, in a right-to-left paragraph that wraps** - a brand name, a URL, an e-mail or a product code straddling the wrap point. UAX #9 rule L2 reorders a *line*, once its breaks are known; it was applied to the whole paragraph, whose word order was then reversed, and the line breaker saw that. `'ا the historical old town ب'` in a 150pt box came out as `historical old town ا` then `ب the`; it is now `the historical old ا` then `ب town`. A paragraph that does not wrap, and a paragraph with no second embedding level, keep the words they had
- **Fix a link annotation or a background over a right-to-left run being narrower than the run.** The box took the decoration's first and last span as its left and right edge, and for a right-to-left run the first span is the rightmost, so most of the words were not clickable. It is the extent over the whole range now
- Right-to-left lines shift by up to a couple of points: each word used to be mirrored by its ink box, which does not tile, and is now placed by its advance
- **Fix an Arabic or Hebrew fragment inside an English paragraph rendering backwards and unjoined** - a name, an address line, a currency symbol. The bidi pass ran only when the resolved direction was `rtl`, and `Directionality` defaults to `ltr`; UAX #9 uses the base direction to pick the embedding level, not to decide whether to run at all. `Text('Total: مرحبا today')` with no `textDirection` now shapes the Arabic and puts it in visual order between the two English words. A paragraph with no strong right-to-left character and no bidi control is skipped, so a left-to-right document is untouched
- Builds with `--dart-define=use_arabic=true`, or `use_bidi=false`: **a blank line inside one `Text` no longer disappears** - the line break was appended in the same statement that skipped the empty line, so each blank line swallowed its own separator - and **a line with no Arabic in it is no longer indented by one space**. Documents on that path reflow: paragraph breaks come back and such lines shift left by a space
- On the same path, an Arabic-range character with no shaped form of its own - a Kurdish letter, an Arabic-Indic digit - keeps its place in the word instead of moving to the other end: `arabic.convert('مائة١٢')` now starts with the digits
- **Fix Arabic drawing as empty boxes with no width in a font that joins through GSUB**, which is what every modern Arabic font does - including `hacen-tunisia`, the font this package's own Arabic sample uses. A glyph is only reachable through the cmap and the shaper substitutes code points, so a font with no code points for its own final, initial and medial glyphs could not be asked for them at all. The `arab` script's `fina`, `init` and `medi` features are read from GSUB now and those glyphs are reachable by the Arabic Presentation Form that stands for them. Only forms the cmap does not already carry are added, so a font that renders today renders the same
- **Fix a font reached through `TextStyle.fontFallback` rendering every character in isolation.** A span was emitted for each unsupported rune on its own, and shaping works on a span, so a one-character span could only ever produce the isolated form: Arabic passed as a fallback came out unjoined, each letter counted as its own word for wrapping, and `TextAlign.justify` stretched the gaps between letters. One span per run of characters served by the same font now, so the fallback draws exactly what it would as the base font. Content streams get fewer, longer runs
- **Fix a non-zero `TextStyle.letterSpacing` adding a gap at every `TextSpan` boundary and after every run of whitespace**, so splitting text into spans moved it and a centred line of several spans sat off centre. At 20pt with `letterSpacing: 5`, the spans 'AAA', 'BBB', 'CCC' start at 0, 55.02 and 110.04, where they used to start at 0, 60.02 and 120.04. No-op at the default `letterSpacing` of 0
- **Fix `maxLines` painting one line too many when the break comes from a `WidgetSpan`** - `RichText` mixing text with inline widgets or emoji. The box was built a line short of what was drawn, so the surplus line landed outside it and on top of whatever followed. Documents tuned around the extra line lose one line
- **Fix a `Text` holding only whitespace laying out to nothing.** `Text('')` and `Text(' ')` both measured 0 x 0, so a table row of empty cells collapsed to a hairline and a `Text(' ')` spacer between two others added no width and ran the words together. A blank paragraph reserves one line of its own font now - at 12pt open-sans, 16.34pt high and 3.12pt wide for a single space - while `TextSpan(text: null)` is still 0 x 0. Layouts that relied on a blank `Text` taking no room get one line taller
- **`TextStyle.height` works.** It was declared, defaulted and carried by `copyWith`, `apply` and `merge`, and read by no layout code: the same paragraph measured the same at height null, 0.5, 1, 2, 4 and 10, so Flutter code ported with `height: 1.5` came out single-spaced. It is a multiple of the natural height of a line in the font, unlike `lineSpacing`, which is absolute points added between lines; a line takes the largest height among its spans, an empty line scales too, and the first baseline does not move. `height: 1` and `height: null` are what they were, so nothing changes unless the field is set
- `TextStyle.apply` can scale `height`, as it already could `fontSize`, `letterSpacing` and `wordSpacing`

## 3.13.2

- Support `currentColor` in SVG fills and strokes, resolved against the inherited `color` property; elements using it were previously not painted at all
- Fix an SVG paint server reference that cannot be resolved crashing the whole document, and honour the fallback colour after `url(...)`
- Fix a gradient declared on an ancestor group being lost by its children, which left the shape unpainted
- Fix an unparsable `stop-color` crashing gradient construction
- Fix the SVG `transparent` keyword painting opaque white, and honour the alpha of `rgba()`, `hsla()` and 8-digit hex colours; fill and stroke alpha no longer bleed into each other

- Fix `Partitions` reporting itself finished as soon as its shortest column ran out, so `MultiPage` advanced past it and dropped whatever the longer columns still had queued
- Fix a null-check crash when a partition wraps a widget that only becomes spannable once it has been built, such as `DefaultTextStyle`

- Fix font subsetting handing an unrelated glyph to, or failing outright on, the second of two characters that share one source glyph. Canonical duplicates (U+0394 and U+2206, U+00AF and U+02C9), any two codepoints the font does not map, and the Arabic presentation forms all collide this way, which made `save()` throw `Missing glyph for character ...` or silently draw the wrong glyph
- Fix subsetting shifting every later character onto the wrong glyph when one glyph index was outside the font's outline table, which emitted an empty subset for a bitmap-only font
- Fix a null-check crash when drawing a space with a font that does not map U+0020

- Fix `PdfColorCmyk.fromRgb` comparing only red against green when looking for the brightest channel, which produced an oversized black and negative components for any colour whose blue exceeds its red, and dividing zero by zero for black, which wrote the literal `NaN` into the document in release builds
- Fix `PdfColorHsl.fromRgb` reporting a saturation of 1.0 for black instead of 0.0
- Fix word splitting cutting between a UTF-16 surrogate pair, which left an unpaired surrogate that no font can map: saving a document with a long run of non-BMP characters (astral CJK, emoji) failed with `Missing glyph for character U+D83C`
- Fix a word that fits the line being hard-split when only the leading whitespace pushed it over the edge

- Fix `MultiPage` allocating pages for ever when a spanning widget placed nothing: it now detects that the widget consumed nothing, retries once on a fresh page and otherwise raises a `PdfException` naming the widget and the space available
- The `maxPages` guard is now checked in release builds too, and bounds consecutive pages produced *without progress* rather than the length of the document, so a document longer than `maxPages` pages no longer fails. A widget that never reports being finished is stopped by a hard ceiling of 10000 pages
- Fix `MultiPage` rejecting a child sized to exactly `availableHeight` (21 of 120 page-format and margin combinations), and measuring 'would it fit on a new page?' against the whole page body instead of the space left by the header and footer, which could loop for ever
- `MultiPage` no longer appends a spanned fragment that placed no content, which painted the widget's decoration over an empty strip
- `Flex`, `Table`, `GridView` and `RichText` now report whether they have more widgets from their saved cursor, so a finished widget no longer forces a trailing page
- Fix a `Column` silently dropping every child from the first one that overflows, which rendered a bounded `Column` as blank space when its first child did not fit. Children are now all laid out and painted, and an overflowing `Flex` clips to its own box; the truncation is kept only when a spanning parent will continue the widget on the next page
- Fix a `GridView` whose cell is taller than the available space placing no row at all, so `MultiPage` never advanced: it allocated pages until the document was abandoned in release builds. Such a row is now emitted and overflows, with a diagnostic in debug builds, and an exhausted `GridView` reports that it has no more widgets instead of adding a trailing blank page
- Fix `Wrap` keying its run lookup by widget identity, so reusing one child instance (a shared spacer, `List.filled`) dropped every child after the first reuse and could stop `MultiPage` from ever advancing

## 3.13.1

- Add output-stream serialization for memory-bounded PDF generation.
- Add lazy JPEG streams that do not retain encoded image bytes.
- Fix setting a dpi on an Image widget massively inflating the PDF size (dart_pdf#1841): never resample above the source resolution, and keep DCT (JPEG) encoding instead of raw Flate pixels when a JPEG image is downsampled. Note that downsampled JPEG images are re-encoded at quality 90 (lossy); omit dpi to embed the original bytes unchanged
- Check the no-upscale rule against the decoded pixels, so rotated images can no longer be accidentally upscaled, and keep the original image when the source resolution is unknown
- Keep dpi downsampling working after the same image was resolved at or above its source resolution
- Strip the source EXIF metadata (GPS position, device serial numbers, ...) from downsampled JPEG images instead of copying it into the document

## 3.13.0

- Fix lint issues
- Update xml dependency
- Add PdfException over the pdf classes
- Made svg path xml functions safer for malformed documents
- Update min dart sdk to 3.12.0

## 3.12.0

- Imroved assertion readability [tmbenhura]
- Dropped unachievable assertion check [tmbenhura]
- Correctly calculating bounding boxes from children [tmbenhura]
- Update pdfa README.md [pldelattre]
- Improve pdfa attached files logic [pldelattre]
- Adds Multipage and Inseparable documentation [Ortes]
- import formxobject [gs]
- Subclasses of PdfFormXObject for drawing widgets and SVG [gs]
- new Method drawXObject [gs]
- feat: add CMYK and Adobe APP14 JPEG support [Michael Ryan]
- fix: handle compound glyph offset calculation and null sub-glyph index [illia-romanenko]
- Improve performance of table layout [Pieter van Loon]
- Reduce freezes on web [Kostia Sokolovskyi]
- creates catalog.names earlier for attached files [ilaurillard]
- fix: Prevent "Index out of range" error when reading simple glyphs in certain fonts  [Eghosa Osayande]
- Improve PdfRect naming consistency
- Migrate to vector_math 2.2.0

## 3.11.3

- Fix CMYK

## 3.11.2

- Add support for custom fonts in SVGs. [Tyler Denniston]
- Fix MultiPage.maxPages not checked with release builds
- Fix PdfColorCmyk.fromRgb
- Table widget refactors [Graham Smith]
- Add support for creating PDF/A 3b [ilaurillard]
- Add helper functions to replace text styles and cell content [Brian Kayfitz]
- Fix TextStyle merge decoration [AtlasAutocode]
- Use secure random number generator for document ID generation

## 3.11.1

- Fixed display problems with textfields [ilaurillard]
- Tighten dependencies

## 3.11.0

- Save in an isolate when available
- NewPage with freeSpace extended [Stefan]

## 3.10.8

- Add Flutter's Logical Pixel constant
- Add support for existing reference objects
- Update barcode golden pdf
- Add support for hyphenation [ilja]
- Add an option to disable bidirectional support [Olzhas-Suleimen]
- Fix operator== type in TextDecoration class
- Fixed wrong empty line height [janiselfert]
- Add Support old Arabic method without bidi package [Baghdady92]

## 3.10.7

- Fix empty lines text gap
- Fix lookup index of glyph for space character [Hendrik-Brower]

## 3.10.6

- Update bidi dependency

## 3.10.5

- Improve TTF writer with multi-compound characters
- Partially revert underline on spans changes
- Add RTL support [Milad-Akarie]
- Fix Arabic fonts missing isolated form [Milad-Akarie]
- Throw multi page error explicitly [Marcin Jeleński]
- Fix deprecations

## 3.10.4

- Fix Deprecation warning message
- TableHelper data accepts Widgets as child
- Add RTL support on TableHelper

## 3.10.3

- Set xml 6.3.0 as minimum dependency

## 3.10.2

- Fix Type1 font widths
- Deprecate PdfArrayObject and PdfObjectDict
- Improve PdfArray and PdfDict constructors
- Fix underline on spans [RomanIvn]
- Improve verbose output
- Allow saving an unmodified document
- Table cell: dynamic widget [Shahriyar Aghajani]
- Move Table.fromTextArray to TableHelper.fromTextArray
- Fix PdfImage constructor without alpha channel [Tomasz Gucio]
- image.fromBytes() pass bytes offset [Aravindhan K]
- Update xml dependency and deprecated getter

## 3.10.1

- Fix web debug build

## 3.10.0

- Apply BoxShape and BorderRadius to selected Checkbox [Joseph Grabinger]
- Fix Color.toHex()
- Improve Annotations placement
- Improve documentation strings
- Improve verbose output
- Import already defined form
- Add support for deleted objects
- Draw page content only if not empty
- Fix Page Content
- Reorganize data types
- Improve Documents conformity
- Make PdfXref a PdfIndirect descendent
- Move Pdf generation settings to PdfSettings
- Improve PdfXrefTable output

## 3.9.0

- Improve TTF Writer compatibility
- Apply THE BIDIRECTIONAL ALGORITHM using dart_bidi [Milad akarie]
- Add Inseparable Widget
- Fix unit tests
- Update Image dependency
- Fix lints
- Add options to customise border in Dataset widget [838]
- Add Choice Field [Carsten Fregin]
- Add Flutter 3.7 compatibility

## 3.8.4

- Improve Multi-Page layout
- Fix SVG stroke-dasharray parsing
- Fix PDF Generation in WEB release build [gopisekaran krd]

## 3.8.3

- Fix Arabic TextAlign.justify issues Set default text align based on text direction [Milad akarie]
- Bump barcode dependency to 2.2.3

## 3.8.2

- Fix Compressed Cross-Reference ID
- Fix exif orientation [deepak786]
- Remove debug print statements

## 3.8.1

- Fix large PDF generation on web with compressed xref
- Fix RangeError Exception When MultiPage Wraps Across Pages [scottdewald]
- Add headerCellDecoration to Table.fromTextArray [Enrique Cardona]

## 3.8.0

- Update xml dependency range
- Implement PointDataSet for Chart
- Implement PdfPageLabels
- Typo: rename "litteral" with "literal"
- Fix tabs and other spaces placeholder
- Prevent modifying the document once saved
- Improve Table Of Content

## 3.7.4

- Fix Bidirectional text (Arabic + Latin words) order and line breakers issue #990 [Milad]

## 3.7.3

- Fix missing endobj with compressed xref
- Fix missing smask subtype
- Add missing final "~>" to Ascii85 encoder
- Fix typo "horizontalCenter"
- Add OverflowBox

## 3.7.2

- Improve debugging information
- Fix parsing TTF fonts with zero-length glyphs

## 3.7.1

- Fix missing chars with pdfjs

## 3.7.0

- Fix imports for Dart 2.15
- Fix TTF font parser for NewsCycle-Regular.ttf
- Move files
- Depreciate Font.stringSize
- Implement fallback font
- Implement Emoji support
- Improve outlines containing non-sequential level increments [Roel Spilker]
- Add debugging information

## 3.6.5

- Update dependencies

## 3.6.4

- Update README

## 3.6.3

- Fix some Spanning Widgets issues
- Fix Arabic unit tests

## 3.6.2

- Fix arabic ranges according to Wikipedia [elibyy]

## 3.6.1

- Fixes crash when array is empty [Kondamon]
- Fix arabic word issues [Mohamedfaroouk]

## 3.6.0

- Fix text justify with multiple paragraphs
- Apply Flutter 2.5 coding style
- Prefere unicode FontName

## 3.5.0

- Add annotations [John Harris]
- Improve image decoding error messages
- Fix Exif decoding

## 3.4.2

- Revert dart format

## 3.4.1

- Fix Nunito font parsing
- Allow reusing an ImageProvider and Font on multiple documents

## 3.4.0

- Fix Text.softWrap behavior
- Add TableOfContent Widget
- Add LinearProgressIndicator
- Add PdfOutline.toString()
- Add equality operator to PdfPageFormat
- Improve TextStyle decoration merging
- Add PdfColor.flatten
- Add A6 page format
- Apply Flutter 2.2 format
- Fix Signature Flags

## 3.3.0

- Implement To be signed fields
- Improve Text rendering
- Add individual cell decoration
- Improve Bullet Widget
- Use covariant on SpanningWidget
- ImageProvider.resolve returns non-null object
- Fix textScalingFactor with lineSpacing
- Implement SpanningWidget on RichText
- Passthrough SpanningWidget on SingleChildWidget and StatelessWidget
- Improve TextOverflow support
- Fix Table horizontalInside borders
- Improve PieChart default colors
- Implement donnut chart

## 3.2.0

- Fix documentation
- Add Positioned.fill()
- Improve GraphicState
- Add SVG Color filter
- Implement Compressed XREF
- Add support for Metadata XML

## 3.1.0

- Fix some linting issues
- Add PdfPage.rotate attribute
- Add RadialGrid for charts with polar coordinates
- Add PieChart
- Fix Text layout with softwrap
- Fix letterSpacing issue

## 3.0.1

- Improve internal null-safety

## 3.0.0

- Fix Checkbox Widget
- Fix SVG colors with percent
- Fix TextField Widget
- Fix border painting with TableRow

## 3.0.0-nullsafety.1

- Fix Table border
- Convert BorderStyle to a class
- Implement dashed Divider

## 3.0.0-nullsafety.0

- Fix SVG fit alignment
- Add DecorationSvgImage
- Opt-In null-safety

## 2.0.0

- A borderRadius can only be given for a uniform Border
- Add LayoutWidgetBuilder
- Add GridPaper widget
- Improve internal structure
- Add some asserts on the TtfParser
- Add document loading
- Remove deprecated methods
- Document.save() now returns a Future
- Add Widget.draw() to paint any widget on a canvas
- Improve Chart labels
- Improve BoxBorder correctness
- Fix Exif parsing with an offset

## 1.13.0

- Implement different border-radius on all corners
- Add AcroForm widgets
- Add document outline support
- Update analysis options
- Fix the line cap and joint enums
- Fix PdfOutlineMode enum
- Improve API documentation
- Add support for Icon Fonts (MaterialIcons)
- Opt-out from dart library
- Improve graphic operations
- Automatically calculate Shape() bounding box
- Improve gradient functions
- Add blend mode
- Add soft-mask support
- Remove dependency to the deprecated utf library
- Fix RichText.maxLines with multiple TextSpan
- Fix Exif parsing
- Add Border and BorderSide objects
- Add basic support for SVG images

## 1.12.0

- Add textDirection parameter to PageTheme
- Fix Bar graph offset
- Implement vertical bar chart

## 1.11.2

- Fix Table.fromTextArray vertical alignment

## 1.11.1

- Fix Table.fromTextArray alignments with multi-lines text
- Fix parameter type typo in Table.fromTextArray [Uli Prantz]

## 1.11.0

- Fix mixing Arabic with English [Anas Altair]
- Support Dagger alif in Arabic [Anas Altair]
- Support ARABIC TATWEEL [Anas Altair]
- Update Arabic tests [Anas Altair]
- Add Directionality Widget

## 1.10.1

- Fix TTF writer with more than 256 CMAP entries

## 1.10.0

- Fix dependencies
- Implement Barcode textPadding and bytes data

## 1.9.0

- Allow MultiPage to re-layout individual pages with support for flex
- Implement BoxShadow for rect and circle BoxDecorations
- Implement TextStyle.letterSpacing
- Implement Arabic writing support [Anas Altair]

## 1.8.1

- Fix Wrap break condition
- Fix drawShape method [Paweł Szot]

## 1.8.0

- Improve Table.fromTextArray()
- Add curved LineDataSet Chart
- Fix PdfColors.fromHex()
- Update Barcode library to 1.9.0
- Fix exif orientation crash
- Fix Spacer Widget

## 1.7.1

- Fix justified text softWrap issue
- Set a default color for Dividers
- Fix InheritedWidget issue with multiple pages

## 1.7.0

- Implement Linear and Radial gradients in BoxDecoration
- Fix PdfColors.shade()
- Add dashed lines to Decoration Widgets
- Add TableRow decoration
- Add Chart Widget [Marco Papula]
- Add Divider and VerticalDivider Widget
- Replace Theme with ThemeData
- Implement ImageProvider
- Improve path operations

## 1.6.2

- Use the Barcode library to generate QR-Codes
- Fix Jpeg size detection
- Update dependency to Barcode 1.8.0
- Fix graphic state operator

## 1.6.1

- Fix Image width and height attributes

## 1.6.0

- Improve Annotations
- Implement table row vertical alignment
- Improve Internal data structure
- Remove deprecated functions
- Optimize file size
- Add PdfColor.shade
- Uniformize examples
- Fix context painting empty Table
- Fix Text decoration placements
- Improve image buffer management
- Optimize memory footprint
- Add an exception if a jpeg image is not a supported format
- Add more image loading functions

## 1.5.0

- Fix Align debug painting
- Fix GridView when empty
- Reorder MultiPage paint operations
- Fix Bullet widget styling
- Fix HSV and HSL Color constructors
- Add PageTheme.copyWith
- Add more font drawing options
- Add Opacity Widget
- Fix Text height with TrueType fonts
- Convert Flex to a SpanningWidget
- Add Partitions Widget
- Fix a TrueType parser issue with some Chinese fonts

## 1.4.1

- Update dependency to barcode ^1.5.0
- Update type1 font warning URL
- Fix Image fit

## 1.4.0

- Improve BarcodeWidget
- Fix BarcodeWidget positioning
- Update dependency to barcode ^1.4.0

## 1.3.29

- Use Barcode stable API

## 1.3.28

- Add Barcode Widget
- Add QrCode Widget

## 1.3.27

- Add Roll Paper support
- Implement custom table widths

## 1.3.26

- Update Analysis options

## 1.3.25

- Add more warnings on type1 fonts
- Simplify PdfImage constructor
- Implement Image orientation
- Add Exif reader
- Add support for GreyScale Jpeg
- Add FullPage widget

## 1.3.24

- Update Web example
- Add more color functions
- Fix Pdf format
- Fix warning in tests
- Fix warning in example
- Format Java code
- Add optional clipping on Page
- Add Footer Widget
- Fix Page orientation
- Add Ascii85 test

## 1.3.23

- Implement ListView.builder and ListView.separated

## 1.3.22

- Fix Text alignment
- Fix Theme creation

## 1.3.21

- Add TextDecoration

## 1.3.20

- Fix Transform.rotateBox
- Add Watermark widget
- Add PageTheme

## 1.3.19

- Fix Ascii85 encoding

## 1.3.18

- Implement InlineSpan and WidgetSpan
- Fix Theme.withFont factory
- Implement InheritedWidget
- Fix Web dependency
- Add Web example

## 1.3.17

- Fix MultiPage with multiple save() calls

## 1.3.16

- Add better debug painting on Align Widget
- Fix Transform placement when Alignment and Origin are Null
- Add Transform.rotateBox constructor
- Add Wrap Widget

## 1.3.15

- Fix Image shape inside BoxDecoration

## 1.3.14

- Add Document ID
- Add encryption support
- Increase PDF version to 1.7
- Add document signature support
- Default compress output if available

## 1.3.13

- Do not modify the TTF font streams

## 1.3.12

- Fix TextStyle constructor

## 1.3.11

- Update Readme

## 1.3.10

- Deprecate the document argument in Printing.sharePdf()
- Add a default value to alpha in PdfColor variants
- Fix Table Widget
- Add Flexible and Spacer Widgets

## 1.3.9

- Fix Transform Widget alignment
- Fix CustomPaint Widget size
- Add DecorationImage to BoxDecoration
- Add default values to ClipRRect

## 1.3.8

- Add jpeg image loading function
- Add Theme::copyFrom() method
- Allow Annotations in TextSpan
- Add SizedBox Widget
- Fix RichText Widget word spacing
- Improve Theme and TextStyle
- Implement properly RichText.softWrap
- Set a proper value to context.pagesCount

## 1.3.7

- Add Pdf Creation date
- Support 64k glyphs per TTF font

## 1.3.6

- Fix TTF Font SubSetting

## 1.3.5

- Add some color functions
- Remove color constants from PdfColor, use PdfColors
- Add TTF Font SubSetting
- Add Unicode support for TTF Fonts
- Add Circular Progress Indicator

## 1.3.4

- Add available dimensions for PdfPageFormat
- Add Document properties
- Add Page.orientation to force landscape or portrait
- Improve MultiPage Widget
- Convert GridView to a SpanningWidget
- Add all Material Colors
- Add Hyperlink widgets

## 1.3.3

- Fix a bug with the RichText Widget
- Update code to Dart 2.1.0
- Add Document.save() method

## 1.3.2

- Fix dart lint warnings
- Improve font bounds calculation
- Add RichText Widget
- Fix MultiPage max-height
- Add Stack Widget
- Update Readme

## 1.3.1

- Fix pana linting notices

## 1.3.0

- Add a Flutter-like Widget system

## 1.2.0

- Change license to Apache 2.0
- Improve PdfRect
- Add support for CMYK, HSL and HSV colors
- Implement rounded rect

## 1.1.1

- Improve PdfPoint and PdfRect
- Change PdfColor.fromInt to const constructor
- Fix drawShape Bézier curves
- Add arcs to SVG drawShape
- Add default page margins
- Change license to Apache 2.0

## 1.1.0

- Rename classes to satisfy Dart conventions
- Remove useless new and const keywords
- Mark some internal functions as protected
- Fix annotations
- Implement default fonts bounding box
- Add Bézier Curve primitive
- Implement drawShape
- Add support for Jpeg images
- Fix numeric conversions in graphic operations
- Add Unicode support for annotations and info block
- Add Flutter example

## 1.0.8

- Fix monospace TTF font loading
- Add PDFPageFormat::toString

## 1.0.7

- Use lowercase page dimension constants

## 1.0.6

- Fix TTF font name lookup

## 1.0.5

- Remove dependency to dart:io
- Add Contributing

## 1.0.4

- Updated homepage
- Update source formatting
- Update README

## 1.0.3

- Remove dependency to ttf_parser

## 1.0.2

- Update SDK support for 2.0.0

## 1.0.1

- Add example
- Lower vector_math dependency version
- Uses better page format object

## 1.0.0

- Initial version
