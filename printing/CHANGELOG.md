# Changelog

## 5.10.2

- Fix Flutter 3.9 deprecations
- Improve podspec files

## 5.10.1

- Fix loading pdfjs in debug mode

## 5.10.0

- Remove deprecated Android embedding
- Add custom pages builder to PdfPreview widget [Milad akarie]
- Update Image dependency
- Fix canChangeOrientation option not appearing bug [Bilal Raja]
- Add Support cmaps option on printing web [Koji Wakamiya]
- Add Flutter 3.7 compatibility

## 5.9.3

- Add an option to shrinkwrap preview and set scrollablePhysics [Damian Bast]
- Resolve driver compatibility issues on Windows [Alban]

## 5.9.2

- Added mounted check for setState in printing>preview>raster [Julius Alibrown]
- Added showsCopies option to print panel [Benjamin Kraatz]
- Support latest version of package:ffi [Xavier Hainaux]
- Update Pdfium to version 5200

## 5.9.1

- iOS: Set cutLength to be currentSize.height [Liam Downey]
- Add Flutter 3 warning workaround
- Improve PdfPreview memory consumption
- Clean up memory usage when using pdf.js [Garrett]
- Specify the device's temp folder on Android [Álvaro Claro]

## 5.9.0

- Typo: change "DownloadbleFont" to "DownloadableFont"
- Remove default .pdf extension added to the Android printJob

## 5.8.0

- PdfPreview supports generic Widgets as actions

## 5.7.5

- Update SWIFT code formatter to version 5
- Fix Xcode 13.3 out of memory issue

## 5.7.4

- Fix orientation not changing
- Fix compilation issues with Swift 6 [Cedric Tegenkamp]

## 5.7.3

- Fix crash when Android load a PDF file which had password
- Fix PdfPreview page format and orientation updates
- Update Pdfium version to 4929
- Automatic pdf.js library loading

## 5.7.2

- Fix dispose state issue
- Add onPageFormatChanged event
- Fix raster quality on Android
- Use a CDN for emoji and cupertino fonts
- Improved Android rendering
- Add dpi attribute to PdfPreview

## 5.7.1

- Update Google Fonts, fixes documentation issues

## 5.7.0

- Fix imports for Dart 2.15
- Fix print dialog crash on Linux
- Fix directPrint printer selection on macOS
- Fix AssetManifest
- Update Google Fonts
- Add a default theme initializer
- Use RENDER_MODE_FOR_DISPLAY on Android
- Enable usage of printer's settings on Windows [Alban Lecuivre]
- Update android projects (mavenCentral, compileSdkVersion 30, gradle:4.1.0)
- Use syscall(SYS_memfd_create) instead of glibc function memfd_create [Obezyan]
- Fix directPrint issue with iOS 15
- Improve PdfPreview actions

## 5.6.6

- Update dependencies

## 3.6.5

- Update README

## 5.6.4

- Fix Windows initial page format

## 5.6.3

- Fix Windows string encoding
- Fix Windows print margins
- Fix macOS printing

## 5.6.2

- Update Linux and Windows pdfium libraries to 4706
- Remove extra scroll bars on desktop [Jonathan Salmon]

## 5.6.1

- Allow host app to override pdfium version [Jon Salmon]

## 5.6.0

- Update Google fonts
- Fix typo in README
- Fix iOS build warning
- Fix pdfium memory leak
- Fix error while loading shared libraries on Linux
- Update pdfium library to 4627
- Apply Flutter 2.5 coding style
- Add WidgetWraper.fromWidget()
- Allow overriding defaultCache

## 5.5.0

- Add custom loading widget to PdfPreview widget

## 5.4.3

- Update Pdfium libraries

## 5.4.2

- Use proper print dialog on Firefox
- Mitigate Safari 14.1.1 print() bug

## 5.4.1

- Always use HTTPS to download Google Fonts

## 5.4.0

- Add Google Fonts support

## 5.3.0

- Fix raster crash on all OS.
- Improve PdfPreview widget
- Fix Linux build on Debian 9
- Added a boolean toggle to show/hide debug switch
- Fix iOS build when not using use_framework!
- Fix WidgetWraper

## 5.2.1

- Fix Linux build

## 5.2.0

- Improve Android page format detection [Deepak]
- Add previewPageMargin and padding parameters [Deepak]
- Fix Scrollbar positionning and default margins
- Add shouldRepaint parameter
- Fix icon colors
- Fix Windows build
- Fix lint warnings

## 5.1.0

- Fix PdfPreview timer dispose [wwl901215]
- Remove unnecessary \_raster call in PdfPreview [yaymalaga]
- Added subject, body and email parameters in sharePdf [Deepak]
- Subject, body and emails parameter to pdf preview [Deepak]

## 5.0.4

- Improve console error reporting

## 5.0.3

- Fix RichText annotations
- Fix rotated pages display on iOS and macOS

## 5.0.2

- Fix iOS/macOS release build not working
- Fix some linting issues
- Fix Web print

## 5.0.1

- Update dependencies

## 5.0.0

- Add imageFromAssetBundle and networkImage
- Add Page orientation on PdfPreview
- Improve PrintJob object
- Implement dynamic layout on iOS and macOS
- Review directPrint internals

## 5.0.0-nullsafety.1

- Fix PdfPreview default locale

## 5.0.0-nullsafety.0

- Remove useless files
- Add WidgetWraper as an ImageProvider insead of wrapWidget()
- Opt-In null-safety

## 4.0.0

- Remove deprecated methods
- Document.save() now returns a Future
- Implement pan and zoom on PdfPreview widget
- Improve orientation handling
- Improve directPrint
- Remove the windows DLL
- Add Linux platform

## 3.7.2

- Fix Printing on WEB
- Fix raster pages on Android and Web

## 3.7.1

- Fix Pdf Raster on WEB
- Fix Windows memory leaks
- Implement missing Windows features

## 3.7.0

- Add beta support for Windows Desktop

## 3.6.4

- Remove useless android dependencies, reduces the final apk file size.

## 3.6.3

- Fix Android compilation issues

## 3.6.2

- Added theme color to dropdown item in pageFormat selector in page preview

## 3.6.1

- Update the example to use PdfPreview
- Add missing `await`s

## 3.6.0

- Added pdfFileName prop to PdfPreview Widget [Marcos Rodriguez]
- Fix PdfPreview unhandled exception when popped [computib]
- Allow to disable actions in PdfPreview [Nicolas Lopez]

## 3.5.0

- Add decoration options to the PdfPreview Widget [Marcos Rodriguez]
- Allow building for Android SDK 16
- Fix font scaling in convertHtml()

## 3.4.0

- Add PdfPreview Widget
- Implement Printing.raster() on Flutter Web
- Fix Swift 5 deprecated function
- Improve code documentation

## 3.3.1

- Remove width and height parameters from wrapWidget helper

## 3.3.0

- Add wrapWidget helper
- Add integration tests for wrapWidget

## 3.2.1

- Add meta and image dependencies

## 3.2.0

- Update README
- Remove deprecated API
- Use plugin_platform_interface
- Fix inconsistent API
- Add Unit tests
- Update example tab
- Uniformize examples
- Optimize memory footprint
- Add PdfRaster.asImage()

## 3.1.0

- Migrate to the new Android plugins APIs
- Fix Android app freeze

## 3.0.2

- Add Raster PDF to Image

## 3.0.1

- Add a link to the Web example

## 3.0.0

Breaking change: this version is only compatible with flutter >= 1.12

- Simplify iOS code
- Improve native code
- Add Printing.info()
- Use PageTheme in example
- Save shared pdf in the cache on Android
- Implement macOS embedding support
- Implement Flutter Web support

## 2.1.9

- Add Markdown example
- Update printing example
- Change the channel name
- Add Builder widget
- Improve Android registration

## 2.1.8

- Revert "Update plugin platforms" (Flutter 1.9.1)

## 2.1.7

- Add iOS Direct Print
- Fix iOS 13 bug

## 2.1.6

- Add QrCode to example
- Cancel print job in case of layout error

## 2.1.5

- Add printing completion

## 2.1.4

- Update example to show saved documents on iOS Files app
- Fix Html to Pdf paper size on iOS

## 2.1.3

- Update Pdf dependency

## 2.1.2

- Update Flutter and Dart dependency

## 2.1.0

- Add HTML to pdf platform conversion
- Fix issue with flutter 1.6.2+

## 2.0.4

- Update Readme

## 2.0.3

- Add file save and view to the example application
- Convert print screen example to Widgets
- Deprecate the document argument in Printing.sharePdf()

## 2.0.2

- Fix example application

## 2.0.1

- Fix Replace FlutterErrorDetails to be compatible with Dart 2.3.0

## 2.0.0

- Breaking change: Switch libraries to AndroidX
- Add Page information to PdfDoc object

## 1.3.5

- Restore compatibility with Flutter 1.0.0
- Update code to Dart 2.1.0
- Depends on pdf 1.3.3

## 1.3.4

- Fix iOS build with Swift
- Add installation instructions in the Readme
- Follow Flutter debug painting settings

## 1.3.3

- Fix dart lint warnings
- Add documentation
- Add a filename parameter for sharing
- Convert Objective-C code to Swift
- Update Readme

## 1.3.2

- Fix iOS printing issues

## 1.3.1

- Fix Pana linting notices

## 1.3.0

- Add a Flutter like Widget system

## 1.2.0

- Fix compileSdkVersion to match AppCompat
- Change license to Apache 2.0
- Implement asynchronous printing driven by the OS

## 1.1.0

- Rename classes to satisfy Dart conventions
- Remove useless new and const keywords
- Changed AppCompat dependency to 26.1.0

## 1.0.6

- Add screenshot example

## 1.0.5

- Fix printing from pdf document

## 1.0.4

- Update example for pdf 1.0.5
- Add Contributing

## 1.0.3

- Update source formatting
- Update README

## 1.0.2

- Add License file
- Updated homepage

## 1.0.1

- Fixed SDK version

## 1.0.0

- Initial release.
