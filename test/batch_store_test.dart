import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aquametrics/data/batch_store.dart';
import 'package:aquametrics/data/frame_cache.dart';
import 'package:aquametrics/models/count_batch.dart';
import 'package:aquametrics/models/marker.dart';
import 'package:aquametrics/vision/count_frame.dart';
import 'package:aquametrics/widgets/batch_tile.dart';
import 'package:aquametrics/widgets/fish_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aquametrics_test_');
    databasePath = '${directory.path}/history.db';
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('persists count metadata, image bytes, and markers', () async {
    final frame = await PhotoFrame.decode(_imageBytes);
    final capturedAt = DateTime(2026, 8, 6, 9, 30);
    final batch = CountBatch(
      id: 'saved-1',
      label: 'Pond transfer',
      species: Species.bangus,
      autoCount: 2,
      manualDelta: 1,
      capturedAt: capturedAt,
      seed: 42,
      note: 'Verified by hand',
    );
    final savedFrame = SavedFrame(
      frame: frame,
      markers: const [
        Marker(p: Offset(0.25, 0.5)),
        Marker(p: Offset(0.75, 0.5), manual: true),
      ],
      ringRadius: 0.031,
    );

    final first = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await first.add(batch, savedFrame);
    await first.close();

    final reopened = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    addTearDown(reopened.close);

    expect(reopened.batches, hasLength(1));
    final restoredBatch = reopened.batches.single;
    expect(restoredBatch.id, batch.id);
    expect(restoredBatch.label, batch.label);
    expect(restoredBatch.species, batch.species);
    expect(restoredBatch.total, 3);
    expect(restoredBatch.capturedAt, capturedAt);
    expect(restoredBatch.note, batch.note);

    final restoredFrame = await reopened.loadFrame(batch.id);
    expect(restoredFrame, isNotNull);
    expect(restoredFrame!.frame.encodedBytes, _imageBytes);
    expect(restoredFrame.ringRadius, closeTo(0.031, 0.000001));
    expect(restoredFrame.markers, hasLength(2));
    expect(restoredFrame.markers.first.p, const Offset(0.25, 0.5));
    expect(restoredFrame.markers.last.manual, isTrue);
  });

  test('migrates an existing history database to add settings', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE count_batches (
              id TEXT PRIMARY KEY,
              label TEXT NOT NULL,
              species TEXT NOT NULL,
              auto_count INTEGER NOT NULL,
              manual_delta INTEGER NOT NULL,
              captured_at INTEGER NOT NULL,
              seed INTEGER NOT NULL,
              note TEXT NOT NULL,
              image_bytes BLOB,
              ring_radius REAL NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE markers (
              batch_id TEXT NOT NULL,
              position INTEGER NOT NULL,
              x REAL NOT NULL,
              y REAL NOT NULL,
              manual INTEGER NOT NULL,
              PRIMARY KEY (batch_id, position)
            )
          ''');
        },
      ),
    );
    await legacy.close();

    final migrated = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    addTearDown(migrated.close);

    expect(migrated.settings.defaultSpecies, Species.tilapia);
    expect(migrated.settings.keepPhotos, isTrue);
  });

  test('persists counting and storage settings', () async {
    final first = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await first.updateSettings(
      const AppSettings(
        defaultSpecies: Species.hito,
        defaultSensitivity: 0.31,
        keepPhotos: false,
        confirmBeforeSave: false,
      ),
    );
    await first.close();

    final reopened = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    addTearDown(reopened.close);

    expect(reopened.settings.defaultSpecies, Species.hito);
    expect(reopened.settings.defaultSensitivity, 0.31);
    expect(reopened.settings.keepPhotos, isFalse);
    expect(reopened.settings.confirmBeforeSave, isFalse);
  });

  test('does not persist images when photo retention is disabled', () async {
    final store = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await store.updateSettings(store.settings.copyWith(keepPhotos: false));
    final frame = await PhotoFrame.decode(_imageBytes);
    await store.add(
      CountBatch(
        id: 'without-photo',
        label: 'No photo',
        species: Species.sugpo,
        autoCount: 1,
        manualDelta: 0,
        capturedAt: DateTime(2026, 8, 6),
        seed: 8,
      ),
      SavedFrame(
        frame: frame,
        markers: const [Marker(p: Offset(0.5, 0.5))],
        ringRadius: 0.03,
      ),
    );
    await store.close();

    final reopened = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    addTearDown(reopened.close);
    expect(reopened.batches, hasLength(1));
    expect(await reopened.loadFrame('without-photo'), isNull);
  });

  test('exports escaped count history as CSV', () {
    final store = BatchStore.memory([
      CountBatch(
        id: 'csv-1',
        label: 'Pond, "North"',
        species: Species.tilapia,
        autoCount: 12,
        manualDelta: -1,
        capturedAt: DateTime.utc(2026, 8, 6, 10, 15),
        seed: 1,
        note: 'Clear water',
      ),
    ]);

    final csv = store.exportCsv();
    expect(csv, contains('"Pond, ""North"""'));
    expect(csv, contains('"12","-1","11"'));
    expect(csv, contains('"2026-08-06T10:15:00.000Z"'));
  });

  testWidgets('batch tile renders its saved photograph', (tester) async {
    final store = BatchStore.memory();
    final batch = CountBatch(
      id: 'thumb-1',
      label: 'Saved photo',
      species: Species.bangus,
      autoCount: 1,
      manualDelta: 0,
      capturedAt: DateTime(2026, 8, 6),
      seed: 3,
    );
    final frame =
        await tester.runAsync(() => PhotoFrame.decode(_imageBytes))
            as PhotoFrame;
    unawaited(
      store.add(
        batch,
        SavedFrame(
          frame: frame,
          markers: const [Marker(p: Offset(0.5, 0.5))],
          ringRadius: 0.03,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchTile(store: store, batch: batch, onTap: () {}),
        ),
      ),
    );
    await tester.pump();

    final thumbnail = tester.widget<CountFrameView>(
      find.byKey(const ValueKey('saved-thumbnail-thumb-1')),
    );
    expect(thumbnail.frame, isA<PhotoFrame>());
    await tester.pumpWidget(const SizedBox.shrink());
    frame.image.dispose();
  });

  test('deleting a count removes its persisted history and image', () async {
    final store = await BatchStore.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final frame = SimulatedFrame.seeded(seed: 7, fish: 1);
    await store.add(
      CountBatch(
        id: 'delete-me',
        label: 'Temporary count',
        species: Species.tilapia,
        autoCount: 1,
        manualDelta: 0,
        capturedAt: DateTime(2026, 8, 6),
        seed: 7,
      ),
      SavedFrame(
        frame: frame,
        markers: [Marker(p: frame.field.spots.single.p)],
        ringRadius: 0.03,
      ),
    );

    await store.remove('delete-me');
    expect(store.batches, isEmpty);
    expect(await store.loadFrame('delete-me'), isNull);
    await store.close();
  });
}
