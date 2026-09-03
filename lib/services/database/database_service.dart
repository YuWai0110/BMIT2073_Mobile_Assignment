import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

abstract class LocalDatabase {
  Future<void> initialize();

  Future<List<Map<String, Object?>>> getEmiSchemes(String userId);

  Future<void> upsertEmiScheme(Map<String, Object?> values);

  Future<void> deleteEmiScheme(String id, String userId);

  Future<List<Map<String, Object?>>> getTriggerRules(String userId);

  Future<void> upsertTriggerRule(Map<String, Object?> values);

  Future<void> deleteTriggerRule(String id, String userId);

  Future<List<Map<String, Object?>>> getNotifications(String userId);

  Future<void> upsertNotification(Map<String, Object?> values);

  Future<void> markNotificationRead(String id, bool isRead, String userId);

  Future<void> deleteNotification(String id, String userId);

  Future<void> clearNotifications(String userId);
}

class DatabaseService implements LocalDatabase {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String databaseName = 'bnm_sme_financing.db';
  static const int databaseVersion = 4;
  static const String legacyTriggerOwner = '__legacy__';
  static const String legacyEmiOwner = '__legacy__';
  static const String legacyNotificationOwner = '__legacy__';
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
        totalPayment REAL NOT NULL,
        user_id TEXT NOT NULL DEFAULT '__legacy__'
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
        user_id TEXT NOT NULL DEFAULT '__legacy__',
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_trigger_rules_user_id '
      'ON $triggerRulesTable(user_id)',
    );
    await database.execute(
      'CREATE INDEX idx_emi_user_id ON $emiSchemesTable(user_id)',
    );
    await database.execute(
      'CREATE INDEX idx_notifications_user_id ON $notificationsTable(user_id)',
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
    if (oldVersion < 3) {
      await database.execute(
        "ALTER TABLE $emiSchemesTable ADD COLUMN user_id TEXT NOT NULL "
        "DEFAULT '$legacyEmiOwner'",
      );
      await database.execute(
        'CREATE INDEX idx_emi_user_id ON $emiSchemesTable(user_id)',
      );
    }
    if (oldVersion < 4) {
      await database.transaction((transaction) async {
        await transaction.execute('''
          CREATE TABLE notifications_v4 (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL DEFAULT '__legacy__',
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            isRead INTEGER NOT NULL
          )
        ''');
        await transaction.execute('''
          INSERT INTO notifications_v4 (
            id, user_id, title, message, timestamp, isRead
          )
          SELECT id, '$legacyNotificationOwner', title, message, timestamp, isRead
          FROM $notificationsTable
        ''');
        await transaction.execute('DROP TABLE $notificationsTable');
        await transaction.execute(
          'ALTER TABLE notifications_v4 RENAME TO $notificationsTable',
        );
        await transaction.execute(
          'CREATE INDEX idx_notifications_user_id '
          'ON $notificationsTable(user_id)',
        );
      });
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
  Future<List<Map<String, Object?>>> getEmiSchemes(String userId) async {
    if (kIsWeb) {
      return _webEmiSchemes.values
          .where((row) => row['user_id'] == userId)
          .map(Map<String, Object?>.from)
          .toList();
    }
    final database = await _readyDatabase;
    return database.query(
      emiSchemesTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'rowid ASC',
    );
  }

  @override
  Future<void> upsertEmiScheme(Map<String, Object?> values) async {
    if (kIsWeb) {
      final userId = values['user_id']! as String;
      _webEmiSchemes['$userId:${values['id']}'] = Map.from(values);
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
  Future<void> deleteEmiScheme(String id, String userId) async {
    if (kIsWeb) {
      _webEmiSchemes.remove('$userId:$id');
      return;
    }
    final database = await _readyDatabase;
    await database.delete(
      emiSchemesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
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
  Future<List<Map<String, Object?>>> getNotifications(String userId) async {
    if (kIsWeb) {
      final rows = _webNotifications.values
          .where((row) => row['user_id'] == userId)
          .map(Map<String, Object?>.from)
          .toList();
      rows.sort(
        (a, b) =>
            (b['timestamp']! as String).compareTo(a['timestamp']! as String),
      );
      return rows;
    }
    final database = await _readyDatabase;
    return database.query(
      notificationsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  @override
  Future<void> upsertNotification(Map<String, Object?> values) async {
    if (kIsWeb) {
      final userId = values['user_id']! as String;
      _webNotifications['$userId:${values['id']}'] = Map.from(values);
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
  Future<void> markNotificationRead(
    String id,
    bool isRead,
    String userId,
  ) async {
    if (kIsWeb) {
      final notification = _webNotifications['$userId:$id'];
      if (notification != null) {
        notification['isRead'] = isRead ? 1 : 0;
      }
      return;
    }
    final database = await _readyDatabase;
    await database.update(
      notificationsTable,
      {'isRead': isRead ? 1 : 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> deleteNotification(String id, String userId) async {
    if (kIsWeb) {
      _webNotifications.remove('$userId:$id');
      return;
    }
    final database = await _readyDatabase;
    await database.delete(
      notificationsTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> clearNotifications(String userId) async {
    if (kIsWeb) {
      _webNotifications.removeWhere((key, _) => key.startsWith('$userId:'));
      return;
    }
    final database = await _readyDatabase;
    await database.delete(
      notificationsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
