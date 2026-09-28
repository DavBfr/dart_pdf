# Changelog

## 5.18.0

- **`Printing.raster` now paints an opaque white page backdrop.** A PDF page has no background of its own - the imaging model leaves it to whatever displays the document - and no native backend painted one, so 96% of a blank A4 came back at alpha 0 and saving a rastered page as PNG, or re-encoding it as JPEG, gave a black page. Pass `background: 0x00000000` to `Printing.raster` for the transparent pages of 5.17 and earlier
- Fix Windows and Linux handing back straight alpha where Flutter reads premultiplied, so a partially transparent page rastered too bright. It made no difference while every pixel was transparent, and none for the new opaque default
- `PrintingPlatform.raster` gained a `background` parameter, which a custom platform implementation has to accept
- **Fix `Printing.raster` hard-crashing the whole process on Windows and Linux** for a page too large to rasterize - an A0 at 600 dpi, an A4 at 3400 dpi. pdfium answers a null bitmap once the buffer reaches 4 GiB, and the pixel loop wrote straight through it; the buffer length and the row offsets were also computed in `int`, which wraps above 2 GiB. The stream now ends with an error naming the problem and the app stays alive
- Every pdfium handle on the Windows and Linux raster paths is released by a scope guard, so the new failure exits cannot skip a close
- Fix the web raster hanging for ever when a page's blob could not be read or the read was aborted: the `FileReader` listener completed its completer only on the success path, and its failure went to the zone rather than to the awaiting code, so `Printing.raster` stopped emitting and never closed and `PdfPreview` sat on a spinner with no error. The read now reports a failure on the stream
- Fix the web raster silently dropping a page when the canvas could not be encoded; it reports which page instead
- Fix the Android raster leaking a full-size temp file in the app cache, two file descriptors and a native `PdfRenderer` on every failure - a password-protected, truncated or malformed document, or an out-of-range page index - which also tripped StrictMode. Every handle is now released on every path, and the temp file is deleted last rather than on the line after the constructor that threw
- An out-of-range page index on Android now ends the raster stream with a message naming the index and the page count, instead of an uncaught `IllegalArgumentException`
- A failed Android raster always reports a non-null message. It could report null, which the Dart side reads as a clean end of stream, and it could report twice




## 5.17.0

- Fix self-hosting pdf.js on web never loading, with 'Failed to resolve module specifier'. A dynamic `import()` reads its argument as a module specifier, so the relative `dartPdfJsBaseUrl` the README documented was a bare specifier the browser rejected. The configured base is now resolved against the page - honouring `<base href>` - and given a trailing slash
- Fix text disappearing on web from PDFs whose CID fonts use a predefined CMap (`UniJIS-UCS2-H`, `GBK-EUC-H`). The CMap configuration was behind a condition that was never true, and the URL it would have built was a 404: `pdfjs-dist` keeps `cmaps/` beside `build/`, not inside it
- A self-hoster whose `cmaps/` directory is not next to the library can point at it with a new `dartPdfJsCMapUrl` window variable
- Configuration values from the page are escaped before being interpolated into the loader script, so a quote in one of them is no longer a syntax error
- The README's pdf.js instructions named version 3.2.146 and the `*.js` loader files, neither of which works with the ES-module pdf.js this package requests
- **`Printing.layoutPdf` on web no longer returns true unconditionally.** It returns false when nothing reached a print dialog: the browser refused to print the frame, the document never loaded, or the browser was handed a download instead. Apps that marked invoices printed, popped a route or showed success off that value were doing so after a cancel, after a failure and after a popup-blocked download
- Fix mobile browsers never attempting to print on web. The strategy is chosen from the browser engine rather than the `Mobile` user-agent token, so an iPhone and an iPad - which sends a desktop user agent - now behave the same instead of one printing and the other silently doing nothing
- The web download fallback now sets the anchor's `download` attribute with the job name instead of `target=_blank`, which iOS Safari blocks when it is clicked after an await. **On Android and in web views, printing on web now downloads the document rather than opening a tab**
- `PrintingInfo` gained `reportsPrintOutcome`, false on web, for an app that treats a print as a committed action
- Fix the web print path leaving the print iframe, its helper script and a full copy of the document in the page whenever the browser's `print()` returned promptly, and never revoking any blob object URL it created. Every print, share and download used to retain the whole document for the lifetime of the tab
- The web print future no longer resolves while the print dialog is still open, and completes false instead of hanging when the browser will not render the document at all
- Fix `PdfPreview` dropping a page format, orientation or debug-switch change made while pages were still streaming. The action bar showed the new setting while the preview kept the old rendering until some unrelated event happened to re-raster. Requests made during a raster now coalesce into one catch-up pass that renders the newest of them
- Fix `PdfPreview` re-running the app's whole document build and a full raster pass on any inherited-widget change - opening the keyboard, toggling dark mode, changing the text scale - even though only the size and the device pixel ratio can move the resolution it renders at
- `PdfPreview` now re-rasters when the window is resized, which it did not do at all
- `PdfPreviewRaster` gained a protected `computeDpi()` and a `needsRasterForDpi` getter, for a subclass that overrides the scheduling
- Fix `PdfPreview` throwing `RangeError` out of `build` - a red error widget the user cannot recover from - when a page was zoomed and a re-raster then produced fewer pages. The zoomed page is clamped to the last page there is, or leaves the zoom when the document is empty, and `onZoomChanged` fires exactly once per real change
- Fix `PdfPreview` re-inflating every page on every rebuild with `enableScrollToPage: true`, which made streaming a document cost O(N^2), and made a key from `getPageKey` dead one frame later. Page keys are now stable for the life of the page
- Fix `scrollToPage` and `getPageKey` throwing `RangeError (length): Valid value range is empty: 0` when called before the first page was rasterized, or past the end after the document shrank. `scrollToPage` now completes without scrolling, and both assert in debug with the index and the page count
- `PdfPreviewCustomState` gained a `pageCount` getter, and `PdfPreviewRaster` a protected `onPagesChanged()` hook called before each page-list change is published
- Fix a change to `PdfPreview`'s `pages`, `dpi` or `maxPageWidth` having no effect until some unrelated event happened to re-raster, at which point the view jumped. Only apps passing `build` as a stable tear-off were affected: a closure literal masked it, because its identity differs on every rebuild. `pages` is compared by content, so a fresh list with the same contents still does not re-raster
- Fix `PdfPreview.onPageFormatChanged` never firing again after the first parent rebuild, so a persisted paper-size choice silently stopped being saved. The replaced `PdfPreviewData` is now also disposed rather than leaked, and the selected format survives the swap
- Fix `PdfPreview` leaking one `ScrollController` per mount, with its listener list. The scroll-position restore scheduled from `build` is guarded, so disposing the controller cannot turn that leak into a 'used after being disposed' crash
- `PdfPreviewCustomState.previewUpdate` is deprecated: it was always null and nothing wrote to it
- **A failed font download now reaches the caller.** `PdfGoogleFonts.*` and `DownloadableFont.getFont` used to return Helvetica on any failure, with their only report inside an assert that release and profile builds strip - so a release build silently shipped a document in which every rune outside 0x00-0xFF was a crossed box. To keep the old behaviour, set `DownloadableFont.defaultFallback = Font.helvetica()` once, or pass `fallback:` to `getFont`; the substitution is then reported through `FlutterError.reportError` in every build mode
- A downloaded body that is not a font - a captive portal's sign-in page, a truncated response - is now a font error naming the font and the URL, and is dropped from the cache, instead of a `RangeError` from inside the TTF reader much later
- `DownloadableFont` is exported, so an app can use it for its own font URLs and set the fallback
- Fix `flutterImageProvider` never completing when the pixel read-back fails, which on the web is what a `NetworkImage` served without CORS headers does: the preview span for ever, `layoutPdf` and `sharePdf` never fired, and no error reached the app. It now rejects with the read-back's own exception, and with a descriptive one naming the image size when the read-back yields no bytes
- A `flutterImageProvider` load failure now rejects with the exception and its stack rather than the string 'image failed to load', and its listener is removed on every path
- Requires pdf_widget_wrapper 1.0.5, in which `WidgetWrapper.fromWidget` works in release and profile builds instead of always throwing, and neither factory leaks its render pipeline or its captured image





## 5.16.0

- Fix roll and undefined page formats sending `double.infinity` over the method channel, which no platform can represent: Android substituted its unknown-size sentinel and laid the document out for Letter, iOS produced NaN margins that ended up as a `NaN` MediaBox, and Windows cast the length into a negative 16-bit field. An unspecified axis is now sent as `0`, meaning 'use the printer's paper for this axis', and each backend treats it that way
- `PdfPreview` now gives a roll format a real height from the page it rasterized while keeping the requested width exactly, so roll printing works from the preview on every backend
- A page size or margin reported back by a platform that is not finite is repaired instead of reaching the document
- Fix the Android media-size match rejecting every candidate for a large page, because the tolerance arithmetic overflowed, and never matching a custom finite format
- Fix the `PdfPreview` share button calling `onPrinted` instead of `onShared`, which left `onShared` as dead code. Apps that relied on `onPrinted` firing for a share must move that handler to `onShared`
- Fix a null-check crash when the preview rebuilds while a share is in flight: the share action read its iPad popover anchor after awaiting the document, by which time its element had been replaced. The anchor is now read before the await, from the context passed to the action
- `PdfShareAction` now reports a failure through `onShareError` and as a `FlutterError` instead of letting it escape as an unhandled asynchronous error, matching the print action. `PdfPreview` gained an `onShareError` parameter to receive it
- `PdfPreviewActionBounds.childKey` and its `bounds` getter are deprecated in favour of `boundsOf(context)`; `bounds` now answers `Rect.zero` rather than throwing when the key is detached
- `Printing.sharePdf` now treats `filename` as a file name rather than a path: any directory part is dropped, and a name that identifies no file falls back to `document.pdf`. Every backend pasted the string onto a temp directory, so a name containing a separator silently shared nothing on most platforms and aborted the Linux plugin
- `Printing.sharePdf` now answers `false` when the platform reports no share instead of reading a missing reply as success, and the Android, iOS, macOS, Linux and Windows backends report whether the file was written and the share sheet actually presented
- Fix the shared document being left behind in the temp directory on iOS and macOS. The copy is now deleted once the share sheet is done with it
- Fix the Android share granting write access to the shared file, and stale entries accumulating in the share directory
- Fix the Linux share ignoring every write error, and leaving a forked copy of the application running when `xdg-open` is missing
- Fix `Printing.layoutPdf` and `Printing.directPrintPdf` never completing on Linux when the document could not be built: `cancel_job` was an empty function, so the future stayed pending, the print dialog stayed alive and everything the job owned leaked. Every Linux job now reports exactly one result, whatever ends it
- Fix Linux leaking one file descriptor and one document-sized memfd per print, which made a long-running app fail with 'Too many open files' after about a thousand prints
- Fix a failed spool write still sending a truncated document to the Linux printer, and reporting a second result for the same job
- Fix Linux never freeing a print job: one leaked per print and per dialog cancel. A cancelled dialog is also destroyed rather than hidden
- Fix the Linux print dialog's printer and page setup being released although they were never acquired, which corrupted their reference counts and crashed the app on a later dialog print
- A Linux print to a queue that accepts no PDF, or with no printer selected, reports that instead of continuing with a null printer
- Fix Windows reporting a successful print for a job that was never spooled. `StartDoc`, `StartPage`, `EndPage` and `EndDoc` are all checked, so `Printing.layoutPdf` now returns false, or throws with the system's message, where it used to return true: cancelling the Print to PDF save dialog, a printer out of paper, access denied and a stopped spooler were all silent successes. A cancellation completes with false rather than throwing
- A failed Windows job aborts the document it opened instead of leaving a half-open job in the queue, and releases its device context and DEVMODE blocks on every path
- Fix `Printing.listPrinters` answering an empty list on Windows when the print system had failed, so an app could not tell that from a machine with no printers. It now reports the failure, and a printer added while the list was being read no longer loses the whole list
- Fix Windows leaking the default-printer name buffer on every `listPrinters` failure
- Fix the classic Windows print dialog leaking one native job object per cancel
- `Printing.listPrinters` answers an empty list rather than throwing a null-check error when a platform reports no printer list at all
- Fix an app that depends on printing and another pdfium plugin failing to configure with 'Build step for pdfium failed: 1', or silently building against the other plugin's pdfium. The Windows and Linux CMake cache entries are now `PRINTING_PDFIUM_VERSION` and `PRINTING_PDFIUM_ARCH`, and the download, source and build trees live under printing's own binary directory instead of `${CMAKE_BINARY_DIR}/pdfium-*`. An app that overrides the version or architecture must use the new names
- Fix the Windows and Linux CMake configure failing with 'string sub-command REPLACE requires at least four arguments' when the app scaffold does not define `FLUTTER_TARGET_PLATFORM`; the architecture now falls back to x64
- Fix `Printing.sharePdf` opening nothing on Android in a background or cached `FlutterEngine` with no Activity. The chooser now carries `FLAG_ACTIVITY_NEW_TASK` when the plugin is bound to the application context, and is unchanged when an Activity is attached
- `Printing.info().canPrint` is now false on Android while no Activity is attached, because `PrintManager` refuses any other context. `Printing.layoutPdf` there completes with a message naming the Activity requirement instead of an anonymous `PlatformException` carrying a raw framework message
- Fix the Android plugin dropping its method-call handler when the Activity is destroyed, which turned every later call in a surviving engine into a `MissingPluginException`. It now falls back to the application context
- No Android framework exception escapes the plugin's method-call handler any more; each one is reported as a `printing` PlatformException naming the call that failed
- Fix Android retaining the last Activity, its Window and its FlutterView for the lifetime of the process after a single print, raster, HTML conversion or share: `PrintingJob` kept the `PrintManager` in a static field, and `PrintManager` holds its Context. The print service is now resolved where it is used and never stored
- Fix the Android system print dialog sitting on 'Preparing preview' with no message when the `onLayout` callback throws. A failure is now reported to the print framework as a failure, carrying the message from Dart, instead of as a cancellation, which dropped it
- Fix the Android print preview hanging when the document could not be written into the print spooler - a full disk, or a descriptor closed because the dialog was dismissed. The write now reports a result on every path, so `Printing.layoutPdf` completes instead of waiting for ever
- Each Android print job now delivers exactly one result to Dart and exactly one terminal callback to the print framework, whatever ends it
- Annotations - highlights, comments, ink, stamps and form widget appearances - are now drawn on iOS and macOS, in `Printing.raster`, `PdfPreview` and printed output. They were silently missing, because the Apple backends ran only the page content stream; Windows and Linux already drew them. Annotations carrying the Hidden flag stay hidden
- Fix a PDF whose MediaBox or CropBox origin is not (0, 0) rastering and printing displaced and clipped on iOS and macOS
- Fix iOS and macOS disagreeing about the pixel size of the same document: macOS sized the raster from the media box and iOS from the crop box. Both now use the crop box, matching Windows and Linux. **macOS raster sizes change for any document with a crop box smaller than its media box**
- Fix a rotated page losing a pixel from one axis when rastered on iOS and macOS; raster sizes are rounded rather than truncated
- A page larger than the paper is now scaled to fit rather than clipped
- The iOS and macOS podspec deployment targets are raised to 13.0 and 10.15, which is what the Swift package manifests already declared
- Fix `Printing.directPrintPdf` with `dynamicLayout: false` never asking for the document on iOS and handing AirPrint an empty job, so nothing printed. The job now starts only once the document has arrived
- Fix the iOS print sheet opening portrait for a landscape format, and always using the generic output type, when `dynamicLayout` is false. The orientation and `outputType` a caller asks for are now used on both paths. **Static-layout sheets now open landscape for a landscape format**
- An iOS print job that cannot be started - the sheet refuses to present, or the printer refuses the job - now reports that, instead of leaving the future pending
- Each iOS print job reports exactly one result to Dart
- Fix `Printing.convertHtml` on macOS returning a single page about 108pt wide and as tall as the whole document, ignoring the requested page format and losing the margins. It renders through a print operation at the requested paper size now, so a document taller than one page is paginated. **The shape of the macOS output changes, and `@media print` rules now apply**
- Fix `Printing.convertHtml` on macOS snapshotting the page one second after starting the load, whatever state it was in: HTML pulling a slow resource converted truncated and was reported as a success, a failed navigation was also reported as a success, and every conversion took at least a second. The conversion now waits for the load to finish, reports a failed navigation as an error, and falls back to rendering whatever exists only after 30 seconds
- No temporary file is left behind by a macOS HTML conversion, and exactly one result is reported per call
- `Printing.listPrinters` on macOS now reports `isDefault`, `isAvailable` and `location`. Every entry used to say `isDefault: false` and `isAvailable: true`, so a picker could not preselect the default and a paused queue looked printable. `comment` stays null, which `Printer.comment` now documents

## 5.15.2

- Fix Windows print jobs hanging forever: opening a named printer, a failing Dart layout callback, an unimplemented reply and a reply carrying no document all deleted the job without reporting anything, so `layoutPdf` and `directPrintPdf` waited for a result that could never arrive. Each now reports the failure and releases the printer device context and settings blocks
- Fix a Windows crash (`std::bad_variant_access`) when the layout reply carries no document, which aborted the whole application
- Fix an unchecked printer capability query on Windows producing a settings block that claimed 65535 bytes of driver data it never allocated
- Fix the Windows settings block being leaked on every print when `usePrinterSettings` is set
- Fix the requested page format never reaching the Windows driver: the form number was always sent as 0, which drivers replace with their own default paper. Standard formats are now sent as their form number, custom sizes as explicit dimensions, and a roll format asks only for the orientation instead of casting infinity into a 16-bit field

- Fix Android `convertHtml` never completing when the print adapter reported a layout or write failure, or a cancellation: those callbacks were not overridden, so the caller's future hung for the lifetime of the process. Every path now delivers exactly one result
- Fix Android `convertHtml` reporting both an error and a success for a document that produced no pages
- Fix Android `convertHtml` leaking its `WebView` and print adapter: they are now owned for the length of the call and torn down once, on the main thread, after the result has been dispatched
- Fix the Android `convertHtml` left margin being 72 times too wide, which pushed the content off the page and produced an empty conversion
- A duplicate or out-of-order platform callback for a job is now ignored instead of raising `Bad state: Future already completed`

- Fix `Printing.raster()` never terminating its stream when the platform call itself fails: the error is now delivered on the stream and the stream closes, instead of leaving `PdfPreview` on a permanent spinner and reporting the error as an unhandled asynchronous error
- Fix `layoutPdf`, `convertHtml` and `raster` leaking their `PrintJob` entry when the platform call throws, which also turned a duplicate platform callback into a confusing `Bad state: Future already completed`
- A raster subscription cancelled early now unregisters its job
- Fix web printing deadlocking for the rest of the session when pdf.js fails to load: the plugin's mutex is now released on every path, the failure is reported to the callers queued behind it instead of having each of them retry, and the module import is bounded by a timeout
- `PdfPreview` now shows its error widget when the platform capabilities cannot be read, instead of an endless loading indicator
- Fix `Mutex` waking every queued waiter at once, which let two callers run inside the same critical section and cleared the lock out from under one of them

## 5.15.1

- Fix iOS use-after-free crash in `CGPDFDocumentGetNumberOfPages`: UIKit reads the PDF document from a background page-count thread while dynamic layout replaces it on the main thread; document access is now lock-guarded
- Fix GHSA-hq66-cqwq-w95j: update pdf.js to 6.2.108
- Fix `RangeError` in `PdfPreviewRaster._raster` when the preview is disposed while a page is being rasterized: re-check `mounted` after awaiting `page.toPng()`, since `dispose()` clears `pages` and the resumed continuation would write to a stale index [PiotrWpl]
- Fix layoutPdf hanging forever in iOS App Store builds: return the document via the method-channel reply instead of a dlsym FFI callback, whose symbols are stripped from statically linked (Swift Package Manager) apps by distribution builds
- Fix iOS/macOS crash (force-unwrapped CGDataProvider) when layoutPdf receives empty or malformed document data
- Fix iOS `convertHtml` crash on iOS 26+ (UISceneDelegate lifecycle): resolve the key window from `connectedScenes` instead of the deprecated `delegate.window`/`keyWindow` lookup [Bilonik]
- Fix Windows memory initialization in `print_job.cpp`: use `dmSize + dmDriverExtra` instead of `sizeof(DEVMODE)` for `ZeroMemory` — `DEVMODE` is a variable-length struct [timothee-escandell]
- Fix Windows and Linux callbacks being routed to the wrong isolate with multiple `FlutterEngine`s (multi-window): the method channel is now owned by the plugin instance instead of a global
- Fix PDFium being destroyed on Windows while another plugin instance is still using it: the library is now reference counted on Windows and Linux
- Fix the Windows print dialog not being owned by the window that started the job with multiple windows

## 5.15.0

- Fix CVE-2024-4367: load pdf.js via ESM import (pdf.js 5.7.284)
- Fix lint issues
- Add Swift Package Manager support
- Fix iOS crash in pickPrinter when the selected printer has a nil URL
- fix printing web override and update pdf dependencies
- Fix Windows PDFium lifecycle
- Implementing support for modern print dialog on windows
- Fix thread issues on iOS and MacOS printing plugin
- Use random starting point for job IDs
- PrintJob list shared between instances to avoid problems with multiple windows.
- Fixed deadlock on macOS with newer Flutter versions & added filtering of redundant pdf layout requests.
- Update min dart sdk to 3.12.0

## 5.14.3

- Update according to breaking changes in the new AssetManifest API [Pierre Fellendael]

## 5.14.2

- Fix wasm dart.pub warning

## 5.14.0

- Replace WebView with WKWebView on macOS
- Upgrade archive [CodeDoctor]
- Fix wasm import [CodeDoctor]

## 5.13.4

- Improve Web Browser detection logic

## 5.13.3

- Update gfonts [Minh-Danh]
- Add compatibility with web 1.1.0

## 5.13.2

- Added new printing output type value on iOS [Matteo Ricupero]
- Workaround for iOS bug and force paper size [Matteo Ricupero]
- Update package:web [Sabin Neupane]
- Force the latest version of pdf_widget_wrapper
- Tighten dependencies
- Update Android build settings

## 5.13.1

- Fix Flutter SDK Minimum version

## 5.13.0

- Migrate to package:web and dart:js_interop
- Set Flutter 3.19 as minimal version
- Fix lints

## 5.12.0

- Refactor html imports
- Implement PdfActionBarTheme for actions bar and add method scrollToPage [Aleksei]
- Update cursors in zoom mode for web [Aleksei]
- Output image sized to cropBox instead of mediaBox (iOS) [garrettApproachableGeek]
- Replace Activity with Context for Service Compatibility (Android) [Heinrich]
- Deprecate support for `convertHtml`
- Implement alternative location for PDF.js [Aleksei]

## 5.11.1

- Use pdfDpi on CPP lib
- set PDFIUM_ARCH according to FLUTTER_TARGET_PLATFORM [nik012003]
- Make pdf background transparent on windows and linux [Mohammad Rasim]

## 5.11.0

- Set Flutter 3.10 as the minimum version
- Fix web builds with Flutter 3.10
- Fix cmake build on Linux and Windows

## 5.10.4

- Update Google Fonts
- Fix CMP0135 policy issue [Jemis Goti]
- Fix raster crash on iOS and MacOS [Eduardo Vital Alencar Cunha]
- Fix wrong format in directPrintPdf [<AlhasanAlQaisi>]
- Add compatibility with Android Gradle Plugin 8.0 [asaarnak]
- Add compatibility with Flutter 3.10
- Re-init UIPrinter cause issues with delegate [Hasan]

## 5.10.3

- Check if widget is mounted before setState [asaarnak]

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
