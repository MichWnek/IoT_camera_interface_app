import 'package:camera_trap_app/data/database/app_database.dart';
import 'package:camera_trap_app/data/database/camera_database_repository.dart';
import 'package:camera_trap_app/data/database/camera_record.dart';
import 'package:camera_trap_app/data/database/sqlite_settings_repository.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late CameraDatabaseRepository cameraRepo;
  late SqliteSettingsRepository settingsRepo;

  setUp(() async {
    db = await AppDatabase.openInMemory(factory: databaseFactoryFfi);
    cameraRepo = CameraDatabaseRepository(db);
    settingsRepo = SqliteSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CameraDatabaseRepository', () {
    test('upserts and reads a full camera record with config and GPS', () async {
      final seenAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final trap = CameraTrap(
        id: 'cam-1',
        name: 'Polana Północna',
        bleMac: '00:11:22:33:44:01',
        status: DeviceStatus(
          batteryPercent: 84,
          sdFreeGb: 12.5,
          isOnline: true,
          lastSeen: seenAt,
        ),
      );

      final record = CameraRecord.fromCameraTrap(
        trap,
        lastConfig: const CameraConfig(aiThreshold: 0.65, pirThreshold: 1.8),
        statusLabel: 'ok',
        location: const CameraLocation(latitude: 50.0647, longitude: 19.9450),
        notes: 'Na sośnie przy strumieniu',
        extra: const {'firmware': '1.0.0'},
      );

      await cameraRepo.upsert(record);

      final loaded = await cameraRepo.getById('cam-1');
      expect(loaded, isNotNull);
      expect(loaded!.toCameraTrap(), equals(trap));
      expect(
        loaded.lastConfig,
        equals(const CameraConfig(aiThreshold: 0.65, pirThreshold: 1.8)),
      );
      expect(loaded.statusLabel, equals('ok'));
      expect(loaded.location?.latitude, equals(50.0647));
      expect(loaded.location?.longitude, equals(19.9450));
      expect(loaded.notes, equals('Na sośnie przy strumieniu'));
      expect(loaded.extra['firmware'], equals('1.0.0'));
    });

    test('supports partial updates for name, status, config, and GPS', () async {
      await cameraRepo.upsert(
        CameraRecord(
          id: 'cam-2',
          name: 'Camera 2',
          bleMac: '00:11:22:33:44:02',
        ),
      );

      await cameraRepo.updateName('cam-2', 'Stara Leśniczówka');
      await cameraRepo.updateStatus(
        'cam-2',
        const DeviceStatus(batteryPercent: 42, sdFreeGb: 3.2, isOnline: false),
      );
      await cameraRepo.updateLastConfig('cam-2', CameraConfig.defaults);
      await cameraRepo.updateLocation(
        'cam-2',
        const CameraLocation(latitude: 49.2992, longitude: 19.9496),
      );
      await cameraRepo.updateStatusLabel('cam-2', 'low_signal');

      final loaded = await cameraRepo.getById('cam-2');
      expect(loaded!.name, equals('Stara Leśniczówka'));
      expect(loaded.status?.batteryPercent, equals(42));
      expect(loaded.lastConfig, equals(CameraConfig.defaults));
      expect(loaded.location?.latitude, equals(49.2992));
      expect(loaded.statusLabel, equals('low_signal'));
    });

    test('deletes a camera by id', () async {
      await cameraRepo.upsert(
        CameraRecord(
          id: 'cam-3',
          name: 'Camera 3',
          bleMac: '00:11:22:33:44:03',
        ),
      );
      await cameraRepo.delete('cam-3');
      expect(await cameraRepo.getById('cam-3'), isNull);
    });
  });

  group('SqliteSettingsRepository', () {
    test('defaults to ThemePreference.system and persists changes', () async {
      expect(
        await settingsRepo.loadThemePreference(),
        equals(ThemePreference.system),
      );

      await settingsRepo.saveThemePreference(ThemePreference.night);
      expect(
        await settingsRepo.loadThemePreference(),
        equals(ThemePreference.night),
      );
    });
  });

  test('generates preview.db file on disk for inspection', () async {
    final dbPath =
        '${Directory.current.path}${Platform.pathSeparator}preview.db';
    final previewDb = await AppDatabase.open(
      customPath: dbPath,
      factory: databaseFactoryFfi,
    );
    final repo = CameraDatabaseRepository(previewDb);
    final settings = SqliteSettingsRepository(previewDb);

    await repo.upsert(
      CameraRecord(
        id: 'cam-1',
        name: 'Polana Północna',
        bleMac: '00:11:22:33:44:01',
        status: const DeviceStatus(
          batteryPercent: 84,
          sdFreeGb: 12.5,
          isOnline: true,
        ),
        lastConfig: const CameraConfig(aiThreshold: 0.65, pirThreshold: 1.8),
        statusLabel: 'ok',
        location: const CameraLocation(latitude: 50.0647, longitude: 19.9450),
        notes: 'Testowy wpis',
        extra: const {'firmware': '1.0.0'},
      ),
    );
    await settings.saveThemePreference(ThemePreference.night);

    final saved = await repo.getAll();
    // ignore: avoid_print
    print('Baza zapisana w: $dbPath');
    // ignore: avoid_print
    print('Rekordy w cameras: ${saved.map((r) => r.toMap()).toList()}');

    await previewDb.close();
  });
}

