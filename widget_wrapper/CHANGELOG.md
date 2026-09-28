# Changelog

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
