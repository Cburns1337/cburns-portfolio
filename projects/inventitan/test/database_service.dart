import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../lib/models/item.dart';

/// Primary DB service (SQLite is source of truth)
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'inventory.db';
  static const _dbVersion = 2; // ← bump to 2 for migration

  static const _table = 'items';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        warehouse TEXT NOT NULL DEFAULT 'Main',
        description TEXT NOT NULL DEFAULT '',
        updatedAt TEXT
      )
    ''');
  }

  /// Migrate v1 (name, quantity, price) → v2 (add warehouse, description, updatedAt)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE $_table ADD COLUMN warehouse TEXT NOT NULL DEFAULT 'Main'");
      await db.execute(
          "ALTER TABLE $_table ADD COLUMN description TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE $_table ADD COLUMN updatedAt TEXT");
    }
  }

  // ---------------------------
  // CRUD
  // ---------------------------

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final rows = await db.query(
      _table,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((m) => Item.fromDbMap(m)).toList();
  }

  Future<Item?> getItemById(int id) async {
    final db = await database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Item.fromDbMap(rows.first);
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    final now = DateTime.now();
    final map = item.copyWith(updatedAt: now).toDbMap();
    // Let SQLite autoincrement the id
    map.remove('id');
    return db.insert(_table, map);
  }

  Future<int> updateItem(Item item) async {
    if (item.id == null) {
      throw ArgumentError('updateItem requires a non-null item.id');
    }
    final db = await database;
    final map = item.copyWith(updatedAt: DateTime.now()).toDbMap();
    return db.update(_table, map, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAll() async {
    final db = await database;
    return db.delete(_table);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}

/// Lightweight wrapper to preserve older call-sites
/// so code like `DatabaseHelper.instance.getAllItems()` still works.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  final _svc = DatabaseService.instance;

  Future<List<Item>> getAllItems() => _svc.getAllItems();
  Future<Item?> getItemById(int id) => _svc.getItemById(id);
  Future<int> insertItem(Item item) => _svc.insertItem(item);
  Future<int> updateItem(Item item) => _svc.updateItem(item);
  Future<int> deleteItem(int id) => _svc.deleteItem(id);
  Future<int> deleteAll() => _svc.deleteAll();
  Future<void> close() => _svc.close();
}
