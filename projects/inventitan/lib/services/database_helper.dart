import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const _dbName = 'inventory.db';
  static const _dbVersion = 3; // ← bumped to add updatedAt
  static const _table = 'items';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
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

    // Helpful indexes for search/filter/sort
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_name ON $_table(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_warehouse ON $_table(warehouse)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add warehouse, description
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE $_table ADD COLUMN warehouse TEXT NOT NULL DEFAULT 'Main'");
      await db.execute("ALTER TABLE $_table ADD COLUMN description TEXT NOT NULL DEFAULT ''");
      await db.execute('CREATE INDEX IF NOT EXISTS idx_items_name ON $_table(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_items_warehouse ON $_table(warehouse)');
    }
    // v2 → v3: add updatedAt
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE $_table ADD COLUMN updatedAt TEXT");
      // await db.execute("UPDATE $_table SET updatedAt = datetime('now')");
    }
  }

  // -----------------------------
  // CRUD
  // -----------------------------

  Future<int> insertItem(Item item) async {
    final db = await instance.database;
    final now = DateTime.now();
    final map = item.copyWith(updatedAt: now).toDbMap();
    map.remove('id'); // let AUTOINCREMENT assign it
    return await db.insert(_table, map);
  }

  Future<List<Item>> getAllItems() async {
    final db = await instance.database;
    final result = await db.query(
      _table,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return result.map((row) => Item.fromDbMap(row)).toList();
  }

  Future<int> updateItem(Item item) async {
    if (item.id == null) {
      throw ArgumentError('updateItem requires a non-null item.id');
    }
    final db = await instance.database;
    final map = item.copyWith(updatedAt: DateTime.now()).toDbMap();
    return await db.update(
      _table,
      map,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }
}
