# Changelog

## 1.1.0

- **Fix captures being embedded as premultiplied pixels where straight alpha is meant**, which put a dark fringe on every anti-aliased edge and made translucent widgets muddy: 50% red rendered as (191,127,127) over white instead of (255,127,127). Both capture paths now ask `dart:ui` for `rawStraightRgba`. A fully opaque capture is byte-identical
- **Fix `buildImage` ignoring a resample request.** `ImageProvider.resolve` asks for a downsample by passing the target width and height, and `WidgetWrapper` handed `PdfImage` the unchanged full-resolution capture labelled with that target - so the RGB and soft-mask loops read at the wrong stride and the embedded picture was a diagonally sheared sliver of the top of the widget, or `Document.save()` threw `RangeError (length): Invalid value: Not in inclusive range 0..319999: 320003` when the target's pixel count exceeded the capture's. It now resamples, as `ImageImage` does, and never upscales
- **Fix a rotated `orientation` scrambling the image.** `buildImage` passed `ImageProvider`'s width and height - display values, which swap the two axes for a rotated orientation - as `PdfImage`'s buffer dimensions, which it writes into `/Width` and `/Height` and uses to walk the pixels. The captured size is now kept separately. Output is unchanged for `topLeft`, `topRight`, `bottomRight` and `bottomLeft`
- Adds a direct dependency on `image`

## 1.0.5

- **Fix `WidgetWrapper.fromWidget` always throwing in release and profile builds.** It read its constraints back out of debug diagnostics, which `DiagnosticPropertiesBuilder` only fills when asserts are enabled, so with asserts off it threw 'Unable to get the widget properties' before rendering anything. The block is gone: the value it recovered was the `ConstrainedBox` argument applied on the line above
- Fix `fromWidget` accepting an unbounded width. It tested `hasBoundedHeight` twice, so an unbounded width fell through to a different check and a different message; it now asks for `maxWidth` and `maxHeight` like an unbounded height does
- Fix `fromWidget` never tearing down the render pipeline it builds. Every call permanently added a `WidgetsBinding` observer on web and on every desktop platform, because `FocusManager`'s constructor registers one and only its `dispose()` removes it, and leaked the `RenderView`, `PipelineOwner` and every render object besides. The teardown runs in a `finally`, so a capture that throws cleans up too
- Fix both factories leaking the full-resolution `ui.Image` they capture

## 1.0.4

- Add compatibility with Flutter 3.20.0-7.0.pre.48

## 1.0.3

- Add compatibility with Flutter 3.19.0

## 1.0.2

- Add compatibility with Flutter 3.18.0-1.0.pre.23

## 1.0.1

- Add compatibility with Flutter 3.10

## 1.0.0

- Initial release.
