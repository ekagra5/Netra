// Local-first storage for patients and scans. Everything the app records
// lives in this on-device SQLite database first; there is no backend to
// sync to yet (see README - the "sync" queue is real UI and real local
// state, but the network leg is intentionally a stub, not faked as working).

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/patient.dart';
import '../models/scan_result.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'netra.db');
    final opened = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER,
            sex TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patientId INTEGER NOT NULL,
            imagePath TEXT NOT NULL,
            heatmapPath TEXT,
            drProbs TEXT NOT NULL,
            dmeProbs TEXT NOT NULL,
            ocularProbs TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            syncStatus TEXT NOT NULL,
            referralUrgency TEXT,
            referralNotes TEXT,
            FOREIGN KEY (patientId) REFERENCES patients (id)
          )
        ''');
      },
    );
    _db = opened;
    return opened;
  }

  Future<int> insertPatient(Patient patient) async {
    final database = await db;
    return database.insert('patients', patient.toMap()..remove('id'));
  }

  Future<List<Patient>> allPatients() async {
    final database = await db;
    final rows = await database.query('patients', orderBy: 'createdAt DESC');
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient?> patientById(int id) async {
    final database = await db;
    final rows = await database.query('patients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  Future<int> insertScan(ScanResult scan) async {
    final database = await db;
    return database.insert('scans', scan.toMap()..remove('id'));
  }

  Future<void> updateScan(ScanResult scan) async {
    final database = await db;
    await database.update('scans', scan.toMap(), where: 'id = ?', whereArgs: [scan.id]);
  }

  Future<List<ScanResult>> scansForPatient(int patientId) async {
    final database = await db;
    final rows = await database.query(
      'scans',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(ScanResult.fromMap).toList();
  }

  Future<List<ScanResult>> allScans() async {
    final database = await db;
    final rows = await database.query('scans', orderBy: 'timestamp DESC');
    return rows.map(ScanResult.fromMap).toList();
  }

  Future<List<ScanResult>> queuedScans() async {
    final database = await db;
    final rows = await database.query(
      'scans',
      where: 'syncStatus != ?',
      whereArgs: [SyncStatus.synced.name],
      orderBy: 'timestamp DESC',
    );
    return rows.map(ScanResult.fromMap).toList();
  }
}
