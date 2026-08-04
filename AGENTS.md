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
flutter test        # 26 tests: 9 detector, 6 editor, 5 flow, 2 calibration,
                    #          2 roboflow parser, 1 roboflow smoke (skipped without key)
```

To run the live Roboflow smoke test:

```sh
flutter test --dart-define=ROBOFLOW_API_KEY=your_key_here \
    test/roboflow_smoke_test.dart
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
- **Third-party dependencies.** Beyond `image_picker` (gallery), the app uses
  `flutter_vision` (on-device YOLO inference, Android only) and `http` (REST
  calls to Roboflow). The UI is still stock Flutter plus `CustomPainter`.
  Don't add more unless there's a real need.
- **Detector selection at startup.** `main()` checks for a Roboflow API key
  (passed via `--dart-define=ROBOFLOW_API_KEY=...`). If present, it creates a
  `RoboflowDetector` (cloud inference via the "fingerlings-dataset-new-n0llf"
  workflow). If not, it loads the on-device YOLO model from
  `assets/models/fish.tflite`. `CountEditor` tries Roboflow first, then YOLO,
  then returns empty — so the app never crashes on detection failure.
- **Detector runs on the UI isolate.** Both Roboflow (HTTP) and YOLO (platform
  channel) are async and run on the UI isolate, not via `compute()`. In widget
  tests, set `debugDetectorRunner` to a function that answers inline —
  otherwise the test cannot settle around the real detector.
- **Roboflow API key.** Passed at compile time, not runtime:
  `flutter run --dart-define=ROBOFLOW_API_KEY=your_key_here`. Get one at
  app.roboflow.com/settings/api. Never commit the key to the repo.
- **Corrections are position-keyed, not index-keyed.** Moving the sensitivity
  slider re-runs the detector and hands back a fresh list of fish in a different
  order. `CountEditor` stores drops and adds as `Offset` positions, so a
  correction survives a re-run and still means the fish that was standing there.

## Deprecated APIs to avoid

Targeting Flutter 3.41, so use:

- `Color.withValues(alpha: ...)`, not `withOpacity`
- `WidgetStateProperty` / `WidgetState`, not `MaterialStateProperty`
- `ColorScheme.surface` and `surfaceContainerHighest`, not `background` or
  `surfaceVariant`

Theme sub-objects that were renamed to `...ThemeData` (`CardThemeData`,
`InputDecorationThemeData`, `AppBarThemeData`) are avoided in
`lib/theme/app_theme.dart`; components are styled inline instead.
