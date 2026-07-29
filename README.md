# AquaMetrics

Count fish fingerlings from a photo.

Point your phone at a tray, take one shot, and AquaMetrics counts what's in the
frame. No clicker, no tallying out loud, no losing your place when someone talks
to you.

Built for hatchery work: bright sun, wet hands, and no signal.

## How you use it

**1. Frame the tray.** Corner guides and an optional grid help you get the whole
tray in shot. Hold it flat and keep your shadow out of the water.

**2. Check the count.** AquaMetrics marks every fingerling it finds and shows you
the total. An automatic count is an estimate, so it's shown as a starting point
rather than the last word.

**3. Fix anything it got wrong.** Tap a ring to drop it, tap open water to add
one it missed. Expand the frame and zoom right into a clump when fish are packed
together — the closer you zoom, the more precise your taps become.

**4. Save it.** Give it a label, pick the species, add a note if something was
odd about the water or the light.

**5. Look back whenever.** Today's running total sits on the home screen, and
every count you've taken is in History, grouped by day and filterable by species.

## Built for the field

- **Readable in glare.** A near-white background with near-black text, rather
  than a dark theme that disappears in direct sun.
- **One obvious action.** The orange button is always the thing to press next,
  and orange is never used for decoration anywhere else.
- **Big targets.** Sized for a thumb, gloved or wet, not a mouse pointer.
- **Yours to correct.** Every count can be adjusted, and any count you changed by
  hand says so, so you can trust the numbers later.
- **Works offline.** Counts live on your phone. No account, no upload, nothing to
  sync before you can get on with the day.

Species: Tilapia, Bangus, Hito and Sugpo.

## Getting started

You'll need Flutter 3.41 or newer. There are no third-party dependencies to
install.

```sh
flutter pub get
flutter devices          # find your phone
flutter run
```

Handy while working on it:

```sh
flutter analyze          # lints and types
flutter test             # widget and unit tests
```

## How the code is laid out

```
lib/
  main.dart                    app entry and theme setup
  theme/app_theme.dart         colour, type and radius tokens
  models/count_batch.dart      a saved count, and the species list
  data/
    batch_store.dart           the list of saved counts, plus totals
    count_editor.dart          one count being reviewed and corrected
  screens/                     home, history, settings, capture,
                               review, full-screen viewer, count details
  widgets/                     buttons, tiles, the frame and marker overlay
  util/format.dart             number, date and time formatting
```

Two pieces are worth knowing about before you change anything:

- **`CountEditor`** holds one count while it's being reviewed: the detection
  threshold and every correction made to it. The inline frame and the full-screen
  viewer both read from a single instance, which is what keeps them in agreement.
- **`fish_field.dart`** owns both the frame and the marker overlay, including the
  ring size. Hit testing reads that same ring size, so what you tap always
  matches what you see.

## Design notes

Numbers use tabular figures everywhere, so a column of counts lines up and can be
compared at a glance.

Motion is kept purposeful: the total settles into place, and the detection sweep
runs while there's work happening and stops when it's done. Nothing animates just
to look busy.
