# Changelog

## 3.4.0

- Fix Text.softWrap behavior
- Add TableOfContent Widget
- Add LinearProgressIndicator
- Add PdfOutline.toString()

## 3.3.0

- Implement To be signed flieds
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
- Improve internal sructure
- Add some asserts on the TtfParser
- Add document loading
- Remove deprecated methods
- Document.save() now returns a Future
- Add Widget.draw() to paint any widget on a canvas
- Improve Chart labels
- Improve BoxBorder correctness
- Fix Exif parsing with an offset

## 1.13.0

- Implement different border radius on all corners
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
- Add soft mask
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

- Allow MultiPage to relayout individual pages with support for flex
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
