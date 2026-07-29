# Agent notes for AquaMetrics

## Environment

The Flutter SDK is **not on `PATH`** on this machine. Prefix commands with:

```sh
export PATH="$HOME/Documents/Flutter/flutter/bin:$PATH"
```

Flutter 3.41.0 / Dart 3.11.0. Android device `R58W41R9ZNH` (SM A245F) is the
usual target; `macos` and `web` are not configured as targets.

## Verification

Run both before considering a change done:

```sh
flutter analyze     # must be clean, including info-level lints
flutter test        # test/count_flow_test.dart, 5 flow tests
```

## Gotchas

- **Test font width.** `flutter test` does not use Roboto; every glyph renders as
  a full-em square, so text measures roughly twice as wide as on a device. A
  `RenderFlex overflowed` error in a test usually means a `Row` is missing a
  `Flexible`/`Expanded` child, not that the layout is broken on a phone. Fix the
  rigidity rather than widening the test surface — it also buys robustness
  against long labels and large system font scales.
- **`Spacer` competes for flex.** `Spacer` is an `Expanded`, so pairing it with
  `Flexible` siblings splits free space between them and starves the content.
  Group the content under one `Expanded` and let fixed-width siblings size
  naturally instead.
- **Transparent overlays swallow taps.** A gradient fade over a scrolling list
  must be wrapped in `IgnorePointer`, or it silently eats taps on the tiles
  underneath. This bit the home screen CTA bar once already.
- **No third-party dependencies.** Keep it that way unless there is a real need;
  the whole UI is stock Flutter plus `CustomPainter`.

## Deprecated APIs to avoid

Targeting Flutter 3.41, so use:

- `Color.withValues(alpha: ...)`, not `withOpacity`
- `WidgetStateProperty` / `WidgetState`, not `MaterialStateProperty`
- `ColorScheme.surface` and `surfaceContainerHighest`, not `background` or
  `surfaceVariant`

Theme sub-objects that were renamed to `...ThemeData` (`CardThemeData`,
`InputDecorationThemeData`, `AppBarThemeData`) are avoided in
`lib/theme/app_theme.dart`; components are styled inline instead.
