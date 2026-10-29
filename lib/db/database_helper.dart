import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/parking_location.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _table = 'parking_location';
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'parking.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          parking_id INTEGER PRIMARY KEY AUTOINCREMENT,
          area_name TEXT NOT NULL,
          floor_number TEXT NOT NULL,
          spot_number TEXT NOT NULL,
          latitude REAL,
          longitude REAL,
          updated_at INTEGER NOT NULL
        )'''),
      // Upgrade from version 1 (keeps old saved spots)
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN latitude REAL');
          await db.execute('ALTER TABLE $_table ADD COLUMN longitude REAL');
        }
      },
    );
  }

  Future<void> addLocation(ParkingLocation l) async {
    final db = await _database;
    await db.insert(_table, l.toMap()..remove('parking_id'));
  }

  Future<List<ParkingLocation>> getLocations() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(ParkingLocation.fromMap).toList();
  }

  Future<void> editLocation(ParkingLocation l) async {
    final db = await _database;
    await db.update(_table, l.toMap(),
        where: 'parking_id = ?', whereArgs: [l.id]);
  }

  Future<void> removeLocation(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'parking_id = ?', whereArgs: [id]);
  }
}