# AquaMetrics

A Flutter app for counting fish fingerlings from a photo of a tray, built for
hatchery work: bright sunlight, wet hands, no signal.

## Status: UI prototype

The interface is complete and navigable. **The counting is not real yet.** Be
clear about what is and is not wired up:

| Area | State |
| --- | --- |
| Screens, navigation, design system | Done |
| Camera preview | Simulated. A painted tray of fingerlings stands in for the live feed, labelled `SIMULATED PREVIEW` on screen. |
| Detection | Simulated. Markers come from the generated field, filtered by the sensitivity slider. No model, no image processing. |
| Manual correction | Fully working against the simulated frame. |
| Persistence | In memory only. Counts are lost when the app restarts. |
| CSV export | Not implemented. The buttons say so. |

The simulation is deliberately structured to match what a real detector returns
— a list of positions with a confidence-like score — so replacing it should not
require reworking the screens.

## Flow

1. **Today** — running total, week and all-time stats, recent counts.
2. **Capture** — framing chrome with corner brackets, guide grid, species
   selector, shutter.
3. **Review** — the number the detector produced, plus the tools to fix it:
   sensitivity slider, tap a ring to drop it, tap open water to add one.
4. **Expand** — the frame full screen, pinch or stepped zoom, still editable.
   Corrections here and on the review screen are the same count.
5. **Save** — label, species, note. Lands in Today and History.

Review is the screen that matters. The detector's number is presented as a
starting point rather than an answer, because a count nobody can check is a
count nobody will trust.

## Running it

Requires Flutter 3.41 / Dart 3.11. There are **no third-party dependencies** —
only `flutter`, `flutter_test` and `flutter_lints`.

```sh
flutter pub get
flutter run              # attach a device first: flutter devices
flutter analyze          # currently clean
flutter test             # see Known issues
```

Verified building and running on Android (Impeller/Vulkan). iOS and Android
folders exist; there is no macOS, web or Windows target.

## Layout

```
lib/
  main.dart                    app entry, light theme only
  theme/app_theme.dart         colour, type and radius tokens
  models/count_batch.dart      CountBatch, Species
  data/
    batch_store.dart           ChangeNotifier over the count list, plus totals
    count_editor.dart          one count under review: threshold + corrections
    mock_data.dart             seeded example counts and the global store
  screens/                     root shell, home, history, settings,
                               capture, review, tray viewer, batch detail
  widgets/
    fish_field.dart            the simulated frame and the marker overlay
    app_buttons.dart           HiVisButton, QuietButton, ExpandChip
    count_widgets.dart         hero card, stats, legends, animated count
  util/format.dart             thousands separators, dates, clock
```

`CountEditor` is worth knowing about: it holds the sensitivity threshold and
every correction, and both the inline frame and the full-screen viewer read from
that one instance. Without it the two views would drift apart.

## Design direction

High contrast for glare, oversized targets for gloves.

- **Shell** near-white `#F1F4F3`, **ink** `#0A1A18` — legible in direct sun.
- **Teal** `#0D5C55` carries structure and the hero card.
- **Safety orange** `#FF7A1A` is reserved for the single primary action on any
  screen. It is never decorative, so it always means "press this".
- Numbers use tabular figures throughout so a column of counts lines up.
- Motion is restrained and purposeful: the count settles, the detector sweep
  runs while work happens and stops when it ends. Nothing loops for decoration.

Species are the ones actually moved locally as fingerlings: Tilapia, Bangus,
Hito, Sugpo.

## Known issues

- `flutter test` fails. The home screen's bottom CTA bar wraps its gradient fade
  in a container that still absorbs pointer events, so taps landing in the
  ~26px transparent fade zone hit the bar instead of the list tile underneath.
  This is a real bug, not a test-only artifact.

## Next, in order

1. Fix the CTA tap-blocking bug above.
2. Local persistence (`sqflite`) behind the existing `BatchStore` interface.
3. Real camera capture (`camera` plugin) plus the Android and iOS permission
   entries, replacing only the bottom layer of `MockTrayImage`.
4. Actual counting. The honest path is classical computer vision, not a magic
   model: Otsu threshold on greyscale, morphological open, connected-component
   labelling, then area-based splitting of touching fish against the median blob
   size. There is no off-the-shelf fingerling model, and training one needs
   labelled trays. Expect approximate results, which is exactly why the manual
   correction step exists.
5. CSV export and share.
