import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

abstract class LocalDatabase {
  Future<void> initialize();

  Future<List<Map<String, Object?>>> getEmiSchemes();

  Future<void> upsertEmiScheme(Map<String, Object?> values);

  Future<void> deleteEmiScheme(String id);

  Future<List<Map<String, Object?>>> getTriggerRules(String userId);

  Future<void> upsertTriggerRule(Map<String, Object?> values);

  Future<void> deleteTriggerRule(String id, String userId);

  Future<List<Map<String, Object?>>> getNotifications();

  Future<void> upsertNotification(Map<String, Object?> values);

  Future<void> markNotificationRead(String id, bool isRead);

  Future<void> deleteNotification(String id);

  Future<void> clearNotifications();
}

class DatabaseService implements LocalDatabase {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String databaseName = 'bnm_sme_financing.db';
  static const int databaseVersion = 2;
  static const String legacyTriggerOwner = '__legacy__';
  static const String emiSchemesTable = 'emi_schemes';
  static const String triggerRulesTable = 'trigger_rules';
  static const String notificationsTable = 'notifications';

  Database? _database;
  final Map<String, Map<String, Object?>> _webEmiSchemes = {};
  final Map<String, Map<String, Object?>> _webTriggerRules = {};
  final Map<String, Map<String, Object?>> _webNotifications = {};

  @override
  Future<void> initialize() async {
    if (kIsWeb || _database != null) {
      return;
    }

    final databasesPath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasesPath, databaseName),
      version: databaseVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $emiSchemesTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        equipmentPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        interestRate REAL NOT NULL,
        loanYears REAL NOT NULL,
        monthlyPayment REAL NOT NULL,
        totalPayment REAL NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE $triggerRulesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        targetRate REAL NOT NULL,
        comparison TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        equipmentType TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE $notificationsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL UNIQUE,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_trigger_rules_user_id '
      'ON $triggerRulesTable(user_id)',
    );
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        "ALTER TABLE $triggerRulesTable ADD COLUMN user_id TEXT NOT NULL "
        "DEFAULT '$legacyTriggerOwner'",
      );
      await database.execute(
        'CREATE INDEX idx_trigger_rules_user_id '
        'ON $triggerRulesTable(user_id)',
      );
    }
  }

  Future<Database> get _readyDatabase async {
    await initialize();
    final database = _database;
    if (database == null) {
      throw StateError('SQLite is not available on this platform');
    }
    return database;
  }

  @override
  Future<List<Map<String, Object?>>> getEmiSchemes() async {
    if (kIsWeb) {
      return _webEmiSchemes.values.map(Map<String, Object?>.from).toList();
    }
    final database = await _readyDatabase;
    return database.query(emiSchemesTable, orderBy: 'rowid ASC');
  }

  @override
  Future<void> upsertEmiScheme(Map<String, Object?> values) async {
    if (kIsWeb) {
      _webEmiSchemes[values['id']! as String] = Map.from(values);
      return;
    }
    final database = await _readyDatabase;
    await database.insert(
      emiSchemesTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteEmiScheme(String id) async {
    if (kIsWeb) {
      _webEmiSchemes.remove(id);
      return;
    }
    final database = await _readyDatabase;
    await database.delete(emiSchemesTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, Object?>>> getTriggerRules(String userId) async {
    if (kIsWeb) {
      return _webTriggerRules.values
          .where((row) => row['user_id'] == userId)
          .map(Map<String, Object?>.from)
          .toList();
    }
    final database = await _readyDatabase;
    return database.query(
      triggerRulesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'createdAt ASC',
    );
  }

  @override
  Future<void> upsertTriggerRule(Map<String, Object?> values) async {
    if (kIsWeb) {
      final key = '${values['user_id']}:${values['id']}';
      _webTriggerRules[key] = Map.from(values);
      return;
    }
    final database = await _readyDatabase;
    await database.insert(
      triggerRulesTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteTriggerRule(String id, String userId) async {
    if (kIsWeb) {
      _webTriggerRules.remove('$userId:$id');
      return;
    }
    final database = await _readyDatabase;
    await database.delete(
      triggerRulesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<List<Map<String, Object?>>> getNotifications() async {
    if (kIsWeb) {
      final rows = _webNotifications.values
          .map(Map<String, Object?>.from)
          .toList();
      rows.sort(
        (a, b) =>
            (b['timestamp']! as String).compareTo(a['timestamp']! as String),
      );
      return rows;
    }
    final database = await _readyDatabase;
    return database.query(notificationsTable, orderBy: 'timestamp DESC');
  }

  @override
  Future<void> upsertNotification(Map<String, Object?> values) async {
    if (kIsWeb) {
      _webNotifications[values['id']! as String] = Map.from(values);
      return;
    }
    final database = await _readyDatabase;
    await database.insert(
      notificationsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> markNotificationRead(String id, bool isRead) async {
    if (kIsWeb) {
      final notification = _webNotifications[id];
      if (notification != null) {
        notification['isRead'] = isRead ? 1 : 0;
      }
      return;
    }
    final database = await _readyDatabase;
    await database.update(
      notificationsTable,
      {'isRead': isRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteNotification(String id) async {
    if (kIsWeb) {
      _webNotifications.remove(id);
      return;
    }
    final database = await _readyDatabase;
    await database.delete(notificationsTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearNotifications() async {
    if (kIsWeb) {
      _webNotifications.clear();
      return;
    }
    final database = await _readyDatabase;
    await database.delete(notificationsTable);
  }
}
