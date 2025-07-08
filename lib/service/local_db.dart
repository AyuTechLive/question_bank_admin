import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;
  String? _currentDatabaseName;
  static const String _masterDbName = 'question_bank_master.db';

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    // If no database is selected, use master database
    _database = await _initDatabase(_masterDbName);
    _currentDatabaseName = _masterDbName;
    return _database!;
  }

  // Get current database info
  String? get currentDatabaseName => _currentDatabaseName;
  bool get hasDatabaseSelected => _currentDatabaseName != null;

  Future<Database> _initDatabase(String dbName) async {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final fullDbPath = path.join(dbPath, dbName);

    return await openDatabase(
      fullDbPath,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Question pairs table
    await db.execute('''
      CREATE TABLE question_pairs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        base_name TEXT NOT NULL UNIQUE,
        question_file_path TEXT NOT NULL,
        answer_file_path TEXT NOT NULL,
        question_file_name TEXT NOT NULL,
        answer_file_name TEXT NOT NULL,
        question_file_size INTEGER NOT NULL,
        answer_file_size INTEGER NOT NULL,
        upload_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        last_accessed TEXT NOT NULL
      )
    ''');

    // Upload queue table
    await db.execute('''
      CREATE TABLE upload_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_pair_id INTEGER NOT NULL,
        stream TEXT NOT NULL,
        level TEXT NOT NULL,
        topic TEXT NOT NULL,
        subtopic TEXT NOT NULL,
        language TEXT NOT NULL,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (question_pair_id) REFERENCES question_pairs (id)
      )
    ''');

    // Database info table (for storing metadata about this database)
    await db.execute('''
      CREATE TABLE database_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        database_name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        questions_folder_path TEXT,
        answers_folder_path TEXT,
        created_at TEXT NOT NULL,
        last_accessed TEXT NOT NULL
      )
    ''');

    debugPrint('Database tables created successfully for: $db');
  }

  // Master database operations for tracking all databases
  Future<Database> _getMasterDatabase() async {
    final dbPath = await getDatabasesPath();
    final masterDbPath = path.join(dbPath, 'question_bank_registry.db');

    return await openDatabase(
      masterDbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE databases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            database_name TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            questions_folder_path TEXT,
            answers_folder_path TEXT,
            question_count INTEGER DEFAULT 0,
            upload_queue_count INTEGER DEFAULT 0,
            total_uploads INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            last_accessed TEXT NOT NULL
          )
        ''');
        debugPrint('Master database registry created');
      },
    );
  }

  // Database Management
  Future<List<DatabaseInfo>> getAllDatabases() async {
    final masterDb = await _getMasterDatabase();
    final List<Map<String, dynamic>> maps = await masterDb.query(
      'databases',
      orderBy: 'last_accessed DESC',
    );

    List<DatabaseInfo> databases = [];
    for (final map in maps) {
      // Get current stats for each database
      try {
        final db = await _initDatabase(map['database_name']);
        final questionCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM question_pairs'),
            ) ??
            0;
        final queueCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM upload_queue'),
            ) ??
            0;
        final totalUploads = Sqflite.firstIntValue(
              await db.rawQuery(
                  'SELECT COALESCE(SUM(upload_count), 0) FROM question_pairs'),
            ) ??
            0;

        // Only close if it's not the currently selected database
        if (map['database_name'] != _currentDatabaseName) {
          await db.close();
        }

        databases.add(DatabaseInfo.fromMap({
          ...map,
          'question_count': questionCount,
          'upload_queue_count': queueCount,
          'total_uploads': totalUploads,
        }));
      } catch (e) {
        debugPrint('Error reading database ${map['database_name']}: $e');
        // Add with zero counts if database is corrupted
        databases.add(DatabaseInfo.fromMap({
          ...map,
          'question_count': 0,
          'upload_queue_count': 0,
          'total_uploads': 0,
        }));
      }
    }

    await masterDb.close();
    return databases;
  }

  Future<void> createNewDatabase({
    required String displayName,
    required String questionsFolder,
    required String answersFolder,
  }) async {
    final sanitizedName = _sanitizeDatabaseName(displayName);
    final dbName =
        '${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.db';

    // Create the new database
    final db = await _initDatabase(dbName);

    // Add database info to the database itself
    await db.insert('database_info', {
      'database_name': dbName,
      'display_name': displayName,
      'questions_folder_path': questionsFolder,
      'answers_folder_path': answersFolder,
      'created_at': DateTime.now().toIso8601String(),
      'last_accessed': DateTime.now().toIso8601String(),
    });

    await db.close();

    // Register in master database
    final masterDb = await _getMasterDatabase();
    await masterDb.insert('databases', {
      'database_name': dbName,
      'display_name': displayName,
      'questions_folder_path': questionsFolder,
      'answers_folder_path': answersFolder,
      'question_count': 0,
      'upload_queue_count': 0,
      'total_uploads': 0,
      'created_at': DateTime.now().toIso8601String(),
      'last_accessed': DateTime.now().toIso8601String(),
    });
    await masterDb.close();

    debugPrint('Created new database: $dbName with display name: $displayName');
  }

  Future<void> selectDatabase(String databaseName) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }

    _database = await _initDatabase(databaseName);
    _currentDatabaseName = databaseName;

    // Update last accessed time in master database
    final masterDb = await _getMasterDatabase();
    await masterDb.update(
      'databases',
      {'last_accessed': DateTime.now().toIso8601String()},
      where: 'database_name = ?',
      whereArgs: [databaseName],
    );
    await masterDb.close();

    debugPrint('Selected database: $databaseName');
  }

  Future<void> deleteDatabase(String databaseName) async {
    // Close current database if it's the one being deleted
    if (_currentDatabaseName == databaseName &&
        _database != null &&
        _database!.isOpen) {
      await _database!.close();
      _database = null;
      _currentDatabaseName = null;
    }

    // Delete the database file
    final dbPath = await getDatabasesPath();
    final fullDbPath = path.join(dbPath, databaseName);
    final file = File(fullDbPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from master database
    final masterDb = await _getMasterDatabase();
    await masterDb.delete(
      'databases',
      where: 'database_name = ?',
      whereArgs: [databaseName],
    );
    await masterDb.close();

    debugPrint('Deleted database: $databaseName');
  }

  Future<void> updateDatabaseStats(String databaseName) async {
    final masterDb = await _getMasterDatabase();

    try {
      final db = await _initDatabase(databaseName);
      final questionCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM question_pairs'),
          ) ??
          0;
      final queueCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM upload_queue'),
          ) ??
          0;
      final totalUploads = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COALESCE(SUM(upload_count), 0) FROM question_pairs'),
          ) ??
          0;

      await masterDb.update(
        'databases',
        {
          'question_count': questionCount,
          'upload_queue_count': queueCount,
          'total_uploads': totalUploads,
          'last_accessed': DateTime.now().toIso8601String(),
        },
        where: 'database_name = ?',
        whereArgs: [databaseName],
      );

      if (databaseName != _currentDatabaseName) {
        await db.close();
      }
    } catch (e) {
      debugPrint('Error updating stats for $databaseName: $e');
    }

    await masterDb.close();
  }

  String _sanitizeDatabaseName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .substring(0, name.length > 20 ? 20 : name.length);
  }

  // Ensure database is connected and ready
  Future<void> ensureDatabaseConnection() async {
    if (_database == null || !_database!.isOpen) {
      if (_currentDatabaseName != null) {
        _database = await _initDatabase(_currentDatabaseName!);
      } else {
        _database = await _initDatabase(_masterDbName);
        _currentDatabaseName = _masterDbName;
      }
    }
  }

  // Question Pairs Management (existing methods remain the same)
  Future<void> insertQuestionPairs(List<LocalQuestionPair> pairs) async {
    await ensureDatabaseConnection();
    final db = await database;
    final batch = db.batch();

    for (final pair in pairs) {
      batch.insert(
        'question_pairs',
        pair.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit();

    // Update stats in master database
    if (_currentDatabaseName != null) {
      await updateDatabaseStats(_currentDatabaseName!);
    }

    debugPrint('Inserted ${pairs.length} question pairs');
  }

  Future<List<LocalQuestionPair>> getAllQuestionPairs() async {
    await ensureDatabaseConnection();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'question_pairs',
      orderBy: 'last_accessed DESC',
    );

    return List.generate(maps.length, (i) {
      return LocalQuestionPair.fromMap(maps[i]);
    });
  }

  Future<void> updateLastAccessed(int pairId) async {
    await ensureDatabaseConnection();
    final db = await database;
    await db.update(
      'question_pairs',
      {'last_accessed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [pairId],
    );
  }

  Future<void> incrementUploadCount(int pairId) async {
    await ensureDatabaseConnection();
    final db = await database;
    await db.rawUpdate(
      'UPDATE question_pairs SET upload_count = upload_count + 1 WHERE id = ?',
      [pairId],
    );

    // Update stats in master database
    if (_currentDatabaseName != null) {
      await updateDatabaseStats(_currentDatabaseName!);
    }

    debugPrint('Incremented upload count for pair ID: $pairId');
  }

  // Upload Queue Management (existing methods remain the same)
  Future<void> addToUploadQueue(UploadQueueItem item) async {
    try {
      await ensureDatabaseConnection();
      final db = await database;

      // Validate the item before inserting
      if (item.questionPairId <= 0) {
        throw Exception('Invalid question pair ID: ${item.questionPairId}');
      }

      final result = await db.insert('upload_queue', item.toMap());
      debugPrint('Successfully added to upload queue with ID: $result');

      // Update stats in master database
      if (_currentDatabaseName != null) {
        await updateDatabaseStats(_currentDatabaseName!);
      }

      debugPrint('Added item to upload queue: ${item.questionPairId}');
    } catch (e) {
      debugPrint('Error in addToUploadQueue: $e');
      debugPrint('Item data: ${item.toMap()}');
      rethrow;
    }
  }

  Future<List<UploadQueueItem>> getUploadQueue() async {
    await ensureDatabaseConnection();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'upload_queue',
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return UploadQueueItem.fromMap(maps[i]);
    });
  }

  Future<void> removeFromUploadQueue(int queueId) async {
    await ensureDatabaseConnection();
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [queueId],
    );

    // Update stats in master database
    if (_currentDatabaseName != null) {
      await updateDatabaseStats(_currentDatabaseName!);
    }

    debugPrint('Removed item from upload queue: $queueId');
  }

  Future<void> clearUploadQueue() async {
    await ensureDatabaseConnection();
    final db = await database;
    await db.delete('upload_queue');

    // Update stats in master database
    if (_currentDatabaseName != null) {
      await updateDatabaseStats(_currentDatabaseName!);
    }

    debugPrint('Cleared upload queue');
  }

  Future<int> getUploadQueueCount() async {
    await ensureDatabaseConnection();
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM upload_queue'),
    );
    return count ?? 0;
  }

  // Get question pair with upload queue data
  Future<List<QuestionPairWithQueue>> getQuestionPairsWithQueue() async {
    await ensureDatabaseConnection();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        qp.*,
        uq.id as queue_id,
        uq.stream,
        uq.level,
        uq.topic,
        uq.subtopic,
        uq.language,
        uq.chapter,
        uq.type,
        uq.created_at as queue_created_at
      FROM question_pairs qp
      LEFT JOIN upload_queue uq ON qp.id = uq.question_pair_id
      ORDER BY qp.upload_count ASC, qp.base_name ASC
    ''');

    final Map<int, QuestionPairWithQueue> pairsMap = {};

    for (final map in maps) {
      final pairId = map['id'] as int;

      if (!pairsMap.containsKey(pairId)) {
        pairsMap[pairId] = QuestionPairWithQueue(
          questionPair: LocalQuestionPair.fromMap(map),
          queueItem: null,
        );
      }

      if (map['queue_id'] != null) {
        pairsMap[pairId]!.queueItem = UploadQueueItem.fromMap(map);
      }
    }

    return pairsMap.values.toList();
  }

  // Cleanup old records
  Future<void> cleanupOldRecords() async {
    await ensureDatabaseConnection();
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    await db.delete(
      'question_pairs',
      where: 'last_accessed < ? AND upload_count = 0',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    debugPrint('Cleaned up old unused question pairs');
  }
}

// Database Info Model
class DatabaseInfo {
  final int? id;
  final String databaseName;
  final String displayName;
  final String? questionsFolderPath;
  final String? answersFolderPath;
  final int questionCount;
  final int uploadQueueCount;
  final int totalUploads;
  final DateTime createdAt;
  final DateTime lastAccessed;

  DatabaseInfo({
    this.id,
    required this.databaseName,
    required this.displayName,
    this.questionsFolderPath,
    this.answersFolderPath,
    this.questionCount = 0,
    this.uploadQueueCount = 0,
    this.totalUploads = 0,
    required this.createdAt,
    required this.lastAccessed,
  });

  factory DatabaseInfo.fromMap(Map<String, dynamic> map) {
    return DatabaseInfo(
      id: map['id']?.toInt(),
      databaseName: map['database_name']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      questionsFolderPath: map['questions_folder_path']?.toString(),
      answersFolderPath: map['answers_folder_path']?.toString(),
      questionCount: map['question_count']?.toInt() ?? 0,
      uploadQueueCount: map['upload_queue_count']?.toInt() ?? 0,
      totalUploads: map['total_uploads']?.toInt() ?? 0,
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      lastAccessed: DateTime.parse(
          map['last_accessed'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'database_name': databaseName,
      'display_name': displayName,
      'questions_folder_path': questionsFolderPath,
      'answers_folder_path': answersFolderPath,
      'question_count': questionCount,
      'upload_queue_count': uploadQueueCount,
      'total_uploads': totalUploads,
      'created_at': createdAt.toIso8601String(),
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }
}

// Existing models remain the same
class LocalQuestionPair {
  final int? id;
  final String baseName;
  final String questionFilePath;
  final String answerFilePath;
  final String questionFileName;
  final String answerFileName;
  final int questionFileSize;
  final int answerFileSize;
  final int uploadCount;
  final DateTime createdAt;
  final DateTime lastAccessed;

  LocalQuestionPair({
    this.id,
    required this.baseName,
    required this.questionFilePath,
    required this.answerFilePath,
    required this.questionFileName,
    required this.answerFileName,
    required this.questionFileSize,
    required this.answerFileSize,
    this.uploadCount = 0,
    required this.createdAt,
    required this.lastAccessed,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'base_name': baseName,
      'question_file_path': questionFilePath,
      'answer_file_path': answerFilePath,
      'question_file_name': questionFileName,
      'answer_file_name': answerFileName,
      'question_file_size': questionFileSize,
      'answer_file_size': answerFileSize,
      'upload_count': uploadCount,
      'created_at': createdAt.toIso8601String(),
      'last_accessed': lastAccessed.toIso8601String(),
    };
  }

  factory LocalQuestionPair.fromMap(Map<String, dynamic> map) {
    return LocalQuestionPair(
      id: map['id']?.toInt(),
      baseName: map['base_name']?.toString() ?? '',
      questionFilePath: map['question_file_path']?.toString() ?? '',
      answerFilePath: map['answer_file_path']?.toString() ?? '',
      questionFileName: map['question_file_name']?.toString() ?? '',
      answerFileName: map['answer_file_name']?.toString() ?? '',
      questionFileSize: map['question_file_size']?.toInt() ?? 0,
      answerFileSize: map['answer_file_size']?.toInt() ?? 0,
      uploadCount: map['upload_count']?.toInt() ?? 0,
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      lastAccessed: DateTime.parse(
          map['last_accessed'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class UploadQueueItem {
  final int? id;
  final int questionPairId;
  final String stream;
  final String level;
  final String topic;
  final String subtopic;
  final String language;
  final String chapter;
  final String type;
  final DateTime createdAt;

  UploadQueueItem({
    this.id,
    required this.questionPairId,
    required this.stream,
    required this.level,
    required this.topic,
    required this.subtopic,
    required this.language,
    required this.chapter,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'question_pair_id': questionPairId,
      'stream': stream,
      'level': level,
      'topic': topic,
      'subtopic': subtopic,
      'language': language,
      'chapter': chapter,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UploadQueueItem.fromMap(Map<String, dynamic> map) {
    return UploadQueueItem(
      id: map['id']?.toInt() ?? map['queue_id']?.toInt(),
      questionPairId: map['question_pair_id']?.toInt() ?? 0,
      stream: map['stream']?.toString() ?? '',
      level: map['level']?.toString() ?? '',
      topic: map['topic']?.toString() ?? '',
      subtopic: map['subtopic']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      chapter: map['chapter']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      createdAt: DateTime.parse(map['created_at'] ??
          map['queue_created_at'] ??
          DateTime.now().toIso8601String()),
    );
  }
}

class QuestionPairWithQueue {
  final LocalQuestionPair questionPair;
  UploadQueueItem? queueItem;

  QuestionPairWithQueue({
    required this.questionPair,
    this.queueItem,
  });

  bool get isInQueue => queueItem != null;
}
