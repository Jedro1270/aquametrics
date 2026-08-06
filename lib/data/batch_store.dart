import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/count_batch.dart';
import '../models/marker.dart';
import '../vision/count_frame.dart';
import 'frame_cache.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.defaultSpecies = Species.tilapia,
    this.defaultSensitivity = 0.72,
  });

  final Species defaultSpecies;
  final double defaultSensitivity;

  AppSettings copyWith({Species? defaultSpecies, double? defaultSensitivity}) =>
      AppSettings(
        defaultSpecies: defaultSpecies ?? this.defaultSpecies,
        defaultSensitivity: defaultSensitivity ?? this.defaultSensitivity,
      );
}

/// Local store for count history. Production instances are backed by SQLite;
/// memory instances keep widget and unit tests independent from platform code.
class BatchStore extends ChangeNotifier {
  BatchStore.memory([
    List<CountBatch> seed = const [],
    AppSettings settings = const AppSettings(),
  ]) : _database = null,
       _batches = [...seed],
       _settings = settings;

  BatchStore._(this._database, this._batches, this._settings);

  static const databaseName = 'aquametrics.db';
  static const _databaseVersion = 2;

  final Database? _database;
  final List<CountBatch> _batches;
  AppSettings _settings;
  final FrameCache _frames = FrameCache();

  static Future<BatchStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? '${await selectedFactory.getDatabasesPath()}/$databaseName';
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
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
          await db.execute('''
            CREATE TABLE markers (
              batch_id TEXT NOT NULL,
              position INTEGER NOT NULL,
              x REAL NOT NULL,
              y REAL NOT NULL,
              manual INTEGER NOT NULL,
              PRIMARY KEY (batch_id, position),
              FOREIGN KEY (batch_id) REFERENCES count_batches (id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX count_batches_captured_at '
            'ON count_batches (captured_at DESC)',
          );
          await _createSettingsTable(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createSettingsTable(db);
        },
      ),
    );
    final rows = await database.query(
      'count_batches',
      orderBy: 'captured_at DESC',
    );
    final settingsRows = await database.query('app_settings', limit: 1);
    return BatchStore._(
      database,
      rows.map(_batchFromRow).toList(),
      _settingsFromRow(settingsRows.single),
    );
  }

  AppSettings get settings => _settings;

  Future<void> updateSettings(AppSettings settings) async {
    await _database?.update(
      'app_settings',
      _settingsToRow(settings),
      where: 'id = 1',
    );
    _settings = settings;
    notifyListeners();
  }

  /// Newest first.
  List<CountBatch> get batches {
    final sorted = [..._batches]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(sorted);
  }

  Future<void> add(CountBatch batch, SavedFrame frame) async {
    final database = _database;
    if (database != null) {
      await database.transaction((transaction) async {
        await transaction.insert('count_batches', {
          ..._batchToRow(batch),
          'image_bytes': frame.frame.encodedBytes,
          'ring_radius': frame.ringRadius,
        });
        final markerBatch = transaction.batch();
        for (var position = 0; position < frame.markers.length; position++) {
          final marker = frame.markers[position];
          markerBatch.insert('markers', {
            'batch_id': batch.id,
            'position': position,
            'x': marker.p.dx,
            'y': marker.p.dy,
            'manual': marker.manual ? 1 : 0,
          });
        }
        await markerBatch.commit(noResult: true);
      });
    }
    _batches.add(batch);
    _frames.put(batch.id, frame);
    notifyListeners();
  }

  Future<SavedFrame?> loadFrame(String batchId) async {
    final cached = _frames[batchId];
    if (cached != null) return cached;
    final database = _database;
    if (database == null) return null;

    final batches = await database.query(
      'count_batches',
      columns: ['image_bytes', 'ring_radius'],
      where: 'id = ?',
      whereArgs: [batchId],
      limit: 1,
    );
    if (batches.isEmpty) return null;
    final imageBytes = batches.single['image_bytes'] as Uint8List?;
    if (imageBytes == null) return null;
    final markerRows = await database.query(
      'markers',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'position',
    );
    final saved = SavedFrame(
      frame: await PhotoFrame.decode(imageBytes),
      markers: [
        for (final row in markerRows)
          Marker(
            p: Offset(row['x'] as double, row['y'] as double),
            manual: row['manual'] == 1,
          ),
      ],
      ringRadius: (batches.single['ring_radius'] as num).toDouble(),
    );
    _frames.put(batchId, saved);
    return saved;
  }

  Future<void> remove(String id) async {
    await _database?.delete('count_batches', where: 'id = ?', whereArgs: [id]);
    _batches.removeWhere((batch) => batch.id == id);
    _frames.remove(id);
    notifyListeners();
  }

  Future<void> close() async => _database?.close();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _sum(Iterable<CountBatch> items) =>
      items.fold(0, (acc, b) => acc + b.total);

  int get todayTotal {
    final now = DateTime.now();
    return _sum(_batches.where((b) => _sameDay(b.capturedAt, now)));
  }

  int get todayCounts =>
      _batches.where((b) => _sameDay(b.capturedAt, DateTime.now())).length;

  DateTime? get lastCapture {
    if (_batches.isEmpty) return null;
    return batches.first.capturedAt;
  }

  int get weekTotal {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _sum(_batches.where((b) => b.capturedAt.isAfter(cutoff)));
  }

  int get allTimeTotal => _sum(_batches);

  String exportCsv() {
    final rows = <String>[
      'id,label,species,automatic_count,manual_adjustment,final_count,'
          'captured_at,note',
      for (final batch in batches)
        [
          batch.id,
          batch.label,
          batch.species.label,
          batch.autoCount,
          batch.manualDelta,
          batch.total,
          batch.capturedAt.toIso8601String(),
          batch.note,
        ].map((value) => _csv(value.toString())).join(','),
    ];
    return '${rows.join('\n')}\n';
  }

  /// Batches grouped into day buckets, newest day first.
  List<(DateTime, List<CountBatch>)> get byDay {
    final buckets = <DateTime, List<CountBatch>>{};
    for (final b in batches) {
      final key = DateTime(
        b.capturedAt.year,
        b.capturedAt.month,
        b.capturedAt.day,
      );
      buckets.putIfAbsent(key, () => []).add(b);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (k, buckets[k]!)];
  }

  static Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        default_species TEXT NOT NULL,
        default_sensitivity REAL NOT NULL,
        keep_photos INTEGER NOT NULL,
        confirm_before_save INTEGER NOT NULL
      )
    ''');
    await db.insert('app_settings', {
      'id': 1,
      ..._settingsToRow(const AppSettings()),
    });
  }

  static Map<String, Object?> _settingsToRow(AppSettings settings) => {
    'default_species': settings.defaultSpecies.name,
    'default_sensitivity': settings.defaultSensitivity,
    'keep_photos': 1,
    'confirm_before_save': 1,
  };

  static AppSettings _settingsFromRow(Map<String, Object?> row) => AppSettings(
    defaultSpecies: Species.values.byName(row['default_species'] as String),
    defaultSensitivity: (row['default_sensitivity'] as num).toDouble(),
  );

  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  static Map<String, Object?> _batchToRow(CountBatch batch) => {
    'id': batch.id,
    'label': batch.label,
    'species': batch.species.name,
    'auto_count': batch.autoCount,
    'manual_delta': batch.manualDelta,
    'captured_at': batch.capturedAt.millisecondsSinceEpoch,
    'seed': batch.seed,
    'note': batch.note,
  };

  static CountBatch _batchFromRow(Map<String, Object?> row) => CountBatch(
    id: row['id'] as String,
    label: row['label'] as String,
    species: Species.values.byName(row['species'] as String),
    autoCount: row['auto_count'] as int,
    manualDelta: row['manual_delta'] as int,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(row['captured_at'] as int),
    seed: row['seed'] as int,
    note: row['note'] as String,
  );
}
