// lib/services/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'autofix.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create reports table
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create vehicle_models table
    await db.execute('''
      CREATE TABLE vehicle_models (
        id INTEGER PRIMARY KEY,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create pending_uploads table for offline changes
    await db.execute('''
      CREATE TABLE pending_uploads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create settings cache table
    await db.execute('''
      CREATE TABLE settings_cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }

  // Cache vehicle models
  Future<void> cacheVehicleModels(List<Map<String, dynamic>> models) async {
    final db = await database;
    final batch = db.batch();

    // Clear existing data
    batch.delete('vehicle_models');

    // Insert new data
    for (var model in models) {
      batch.insert('vehicle_models', {
        'id': model['id'],
        'brand': model['brand'],
        'model': model['Model name'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedVehicleModels() async {
    final db = await database;
    return await db.query('vehicle_models', orderBy: 'brand ASC');
  }

  // Cache reports
  Future<void> cacheReports(List<Map<String, dynamic>> reports) async {
    final db = await database;
    final batch = db.batch();

    // Clear existing data
    batch.delete('reports');

    // Insert new data
    for (var report in reports) {
      batch.insert('reports', {
        'id': report['id'],
        'data': jsonEncode(report),
        'synced': 1,
        'created_at': report['created_at'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedReports() async {
    final db = await database;
    final results = await db.query('reports', orderBy: 'created_at DESC');

    return results.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // Pending uploads (for offline mode)
  Future<int> addPendingUpload({
    required String tableName,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;

    return await db.insert('pending_uploads', {
      'table_name': tableName,
      'action': action,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final db = await database;
    return await db.query('pending_uploads', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingUpload(int id) async {
    final db = await database;
    await db.delete('pending_uploads', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingUploadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_uploads');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Settings cache
  Future<void> cacheSetting(String key, String value) async {
    final db = await database;

    await db.insert(
      'settings_cache',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCachedSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings_cache',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('reports');
    await db.delete('vehicle_models');
    await db.delete('settings_cache');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}