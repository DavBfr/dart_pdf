# Changelog

## 1.3.17

* Fix MultiPage with multiple save() calls

## 1.3.16

* Add better debugPaint on Align Widget
* Fix Transform placement when Alignment and Origin are Null
* Add Transform.rotateBox constructor
* Add Wrap Widget

## 1.3.15

* Fix Image shape inside BoxDecoration

## 1.3.14

* Add Document ID
* Add encryption support
* Increase PDF version to 1.7
* Add document signature support
* Default compress output if available

## 1.3.13

* Do not modify the TTF font streams

## 1.3.12

* Fix TextStyle constructor

## 1.3.11

* Update Readme

## 1.3.10

* Deprecate the document argument in Printing.sharePdf()
* Add default value to alpha in PdfColor variants
* Fix Table Widget
* Add Flexible and Spacer Widgets

## 1.3.9

* Fix Transform Widget alignment
* Fix CustomPaint Widget size
* Add DecorationImage to BoxDecoration
* Add default values to ClipRRect

## 1.3.8

* Add jpeg image loading function
* Add Theme::copyFrom() method
* Allow Annotations in TextSpan
* Add SizedBox Widget
* Fix RichText Widget word spacing
* Improve Theme and TextStyle
* Implement properly RichText.softWrap
* Set a proper value to context.pagesCount

## 1.3.7

* Add Pdf Creation date
* Support 64k glyphs per TTF font

## 1.3.6

* Fix TTF Font SubSetting

## 1.3.5

* Add some color functions
* Remove color constants from PdfColor, use PdfColors
* Add TTF Font SubSetting
* Add Unicode support for TTF Fonts
* Add Circular Progress Indicator

## 1.3.4

* Add available dimensions for PdfPageFormat
* Add Document properties
* Add Page.orientation to force landscape or portrait
* Improve MultiPage Widget
* Convert GridView to a SpanningWidget
* Add all Material Colors
* Add Hyperlink widgets

## 1.3.3

* Fix a bug with the RichText Widget
* Update code to Dart 2.1.0
* Add Document.save() method

## 1.3.2

* Fix dart lint warnings
* Improve font bounds calculation
* Add RichText Widget
* Fix MultiPage max height
* Add Stack Widget
* Update Readme

## 1.3.1

* Fix pana linting notices

## 1.3.0

* Add a Flutter like widget system

## 1.2.0

* Change license to Apache 2.0
* Improve PdfRect
* Add support for CMYK, HSL anf HSV colors
* Implement rounded rect

## 1.1.1

* Improve PdfPoint and PdfRect
* Change PdfColor.fromInt to const constructor
* Fix drawShape Bézier curves
* Add arcs to SVG drawShape
* Add default page margins
* Change license to Apache 2.0

## 1.1.0

* Rename classes to satisfy Dart conventions
* Remove useless new and const keywords
* Mark some internal functions as protected
* Fix annotations
* Implement default fonts bounding box
* Add Bézier Curve primitive
* Implement drawShape
* Add support for Jpeg images
* Fix numeric conversions in graphic operations
* Add unicode support for annotations and info block
* Add Flutter example

## 1.0.8

* Fix monospace TTF font loading
* Add PDFPageFormat::toString

## 1.0.7

* Use lowercase page dimension constants

## 1.0.6

* Fix TTF font name lookup

## 1.0.5

* Remove dependency to dart:io
* Add Contributing

## 1.0.4

* Updated homepage
* Update source formatting
* Update README

## 1.0.3

* Remove dependency to ttf_parser

## 1.0.2

* Update sdk support for 2.0.0

## 1.0.1

* Add example
* Lower vector_math dependency version
* Uses better page format object

## 1.0.0

* Initial version
