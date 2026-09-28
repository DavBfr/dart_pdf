# Changelog

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
