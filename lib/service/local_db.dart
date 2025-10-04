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
    _database = await _initDatabase(_masterDbName);
    _currentDatabaseName = _masterDbName;
    return _database!;
  }

  String? get currentDatabaseName => _currentDatabaseName;
  bool get hasDatabaseSelected => _currentDatabaseName != null;

  Future<Database> _initDatabase(String dbName) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final fullDbPath = path.join(dbPath, dbName);

    return await openDatabase(
      fullDbPath,
      version: 3, // CHANGE: Updated version for tags support
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> updateTagUsage(List<String> tags) async {
    if (tags.isEmpty) return;

    await ensureDatabaseConnection();
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final tag in tags) {
      // Insert or update tag usage
      batch.rawInsert('''
        INSERT INTO tag_usage (tag_name, usage_count, last_used, created_at)
        VALUES (?, 1, ?, ?)
        ON CONFLICT(tag_name) DO UPDATE SET
          usage_count = usage_count + 1,
          last_used = ?
      ''', [tag, now, now, now]);
    }

    await batch.commit();
    debugPrint('Updated usage for ${tags.length} tags');
  }

  Future<List<Map<String, dynamic>>> getTagUsageStats({int limit = 20}) async {
    await ensureDatabaseConnection();
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tag_usage',
      orderBy: 'usage_count DESC, last_used DESC',
      limit: limit,
    );

    return maps;
  }

  Future<List<String>> getPopularTags({int limit = 10}) async {
    final stats = await getTagUsageStats(limit: limit);
    return stats.map((stat) => stat['tag_name'] as String).toList();
  }

  Future<List<String>> getRecentTags({int limit = 10}) async {
    await ensureDatabaseConnection();
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tag_usage',
      orderBy: 'last_used DESC',
      limit: limit,
    );

    return maps.map((map) => map['tag_name'] as String).toList();
  }

  Future<void> _createTables(Database db, int version) async {
    // Question pairs table with PDF support (unchanged)
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
        question_pdf_path TEXT,
        answer_pdf_path TEXT,
        question_pdf_name TEXT,
        answer_pdf_name TEXT,
        question_pdf_size INTEGER,
        answer_pdf_size INTEGER,
        pdf_converted_at TEXT,
        upload_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        last_accessed TEXT NOT NULL
      )
    ''');

    // MODIFY: Enhanced upload queue table with tags
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
        tags TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (question_pair_id) REFERENCES question_pairs (id)
      )
    ''');

    // Database info table (unchanged)
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

    // PDF conversion cache table (unchanged)
    await db.execute('''
      CREATE TABLE pdf_conversion_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_file_path TEXT NOT NULL UNIQUE,
        original_file_hash TEXT,
        pdf_file_path TEXT NOT NULL,
        pdf_file_size INTEGER,
        conversion_date TEXT NOT NULL,
        last_accessed TEXT NOT NULL,
        is_valid INTEGER DEFAULT 1
      )
    ''');

    // ADD: New table for tag usage statistics
    await db.execute('''
      CREATE TABLE tag_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_name TEXT NOT NULL UNIQUE,
        usage_count INTEGER DEFAULT 0,
        last_used TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    debugPrint('Database tables created successfully with tags support');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add PDF support columns (existing migration)
      try {
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN question_pdf_path TEXT');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN answer_pdf_path TEXT');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN question_pdf_name TEXT');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN answer_pdf_name TEXT');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN question_pdf_size INTEGER');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN answer_pdf_size INTEGER');
        await db.execute(
            'ALTER TABLE question_pairs ADD COLUMN pdf_converted_at TEXT');

        await db.execute('''
          CREATE TABLE pdf_conversion_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            original_file_path TEXT NOT NULL UNIQUE,
            original_file_hash TEXT,
            pdf_file_path TEXT NOT NULL,
            pdf_file_size INTEGER,
            conversion_date TEXT NOT NULL,
            last_accessed TEXT NOT NULL,
            is_valid INTEGER DEFAULT 1
          )
        ''');

        debugPrint('Database upgraded to version 2 with PDF support');
      } catch (e) {
        debugPrint('Error during PDF upgrade: $e');
      }
    }

    // ADD: Version 3 upgrade for tags support
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE upload_queue ADD COLUMN tags TEXT DEFAULT ""');

        await db.execute('''
          CREATE TABLE tag_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tag_name TEXT NOT NULL UNIQUE,
            usage_count INTEGER DEFAULT 0,
            last_used TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        debugPrint('Database upgraded to version 3 with tags support');
      } catch (e) {
        debugPrint('Error during tags upgrade: $e');
      }
    }
  }

  // PDF Conversion Cache Methods
  Future<String?> getCachedPdfPath(String originalFilePath) async {
    await ensureDatabaseConnection();
    final db = await database;

    try {
      // Check if file exists and get its modification time
      final originalFile = File(originalFilePath);
      if (!originalFile.existsSync()) return null;

      final originalStat = await originalFile.stat();
      final originalHash =
          '${originalStat.size}_${originalStat.modified.millisecondsSinceEpoch}';

      final List<Map<String, dynamic>> maps = await db.query(
        'pdf_conversion_cache',
        where:
            'original_file_path = ? AND original_file_hash = ? AND is_valid = 1',
        whereArgs: [originalFilePath, originalHash],
      );

      if (maps.isNotEmpty) {
        final cachedPdfPath = maps.first['pdf_file_path'] as String;

        // Verify PDF file still exists
        if (File(cachedPdfPath).existsSync()) {
          // Update last accessed time
          await db.update(
            'pdf_conversion_cache',
            {'last_accessed': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [maps.first['id']],
          );

          debugPrint('Using cached PDF: $cachedPdfPath');
          return cachedPdfPath;
        } else {
          // Mark cache entry as invalid
          await db.update(
            'pdf_conversion_cache',
            {'is_valid': 0},
            where: 'id = ?',
            whereArgs: [maps.first['id']],
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting cached PDF path: $e');
    }

    return null;
  }

  Future<void> cachePdfConversion(
      String originalFilePath, String pdfFilePath) async {
    await ensureDatabaseConnection();
    final db = await database;

    try {
      final originalFile = File(originalFilePath);
      final pdfFile = File(pdfFilePath);

      if (!originalFile.existsSync() || !pdfFile.existsSync()) return;

      final originalStat = await originalFile.stat();
      final pdfStat = await pdfFile.stat();
      final originalHash =
          '${originalStat.size}_${originalStat.modified.millisecondsSinceEpoch}';

      await db.insert(
        'pdf_conversion_cache',
        {
          'original_file_path': originalFilePath,
          'original_file_hash': originalHash,
          'pdf_file_path': pdfFilePath,
          'pdf_file_size': pdfStat.size,
          'conversion_date': DateTime.now().toIso8601String(),
          'last_accessed': DateTime.now().toIso8601String(),
          'is_valid': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Cached PDF conversion: $originalFilePath -> $pdfFilePath');
    } catch (e) {
      debugPrint('Error caching PDF conversion: $e');
    }
  }

  Future<void> updateQuestionPairPdfPaths(
      int pairId, String? questionPdfPath, String? answerPdfPath) async {
    await ensureDatabaseConnection();
    final db = await database;

    try {
      final updateData = <String, dynamic>{
        'pdf_converted_at': DateTime.now().toIso8601String(),
      };

      if (questionPdfPath != null) {
        final pdfFile = File(questionPdfPath);
        if (pdfFile.existsSync()) {
          final pdfStat = await pdfFile.stat();
          updateData['question_pdf_path'] = questionPdfPath;
          updateData['question_pdf_name'] = path.basename(questionPdfPath);
          updateData['question_pdf_size'] = pdfStat.size;
        }
      }

      if (answerPdfPath != null) {
        final pdfFile = File(answerPdfPath);
        if (pdfFile.existsSync()) {
          final pdfStat = await pdfFile.stat();
          updateData['answer_pdf_path'] = answerPdfPath;
          updateData['answer_pdf_name'] = path.basename(answerPdfPath);
          updateData['answer_pdf_size'] = pdfStat.size;
        }
      }

      await db.update(
        'question_pairs',
        updateData,
        where: 'id = ?',
        whereArgs: [pairId],
      );

      debugPrint('Updated question pair $pairId with PDF paths');
    } catch (e) {
      debugPrint('Error updating question pair PDF paths: $e');
    }
  }

  // Clean up old PDF cache entries
  Future<void> cleanupPdfCache() async {
    await ensureDatabaseConnection();
    final db = await database;

    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      // Get old cache entries
      final List<Map<String, dynamic>> oldEntries = await db.query(
        'pdf_conversion_cache',
        where: 'last_accessed < ? OR is_valid = 0',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      // Delete PDF files and cache entries
      for (final entry in oldEntries) {
        try {
          final pdfFile = File(entry['pdf_file_path'] as String);
          if (pdfFile.existsSync()) {
            await pdfFile.delete();
          }
        } catch (e) {
          debugPrint('Error deleting cached PDF file: $e');
        }
      }

      // Remove cache entries
      await db.delete(
        'pdf_conversion_cache',
        where: 'last_accessed < ? OR is_valid = 0',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      debugPrint('Cleaned up old PDF cache entries');
    } catch (e) {
      debugPrint('Error cleaning up PDF cache: $e');
    }
  }

  // Master database operations
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

    final db = await _initDatabase(dbName);

    await db.insert('database_info', {
      'database_name': dbName,
      'display_name': displayName,
      'questions_folder_path': questionsFolder,
      'answers_folder_path': answersFolder,
      'created_at': DateTime.now().toIso8601String(),
      'last_accessed': DateTime.now().toIso8601String(),
    });

    await db.close();

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
    if (_currentDatabaseName == databaseName &&
        _database != null &&
        _database!.isOpen) {
      await _database!.close();
      _database = null;
      _currentDatabaseName = null;
    }

    final dbPath = await getDatabasesPath();
    final fullDbPath = path.join(dbPath, databaseName);
    final file = File(fullDbPath);
    if (await file.exists()) {
      await file.delete();
    }

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

      if (item.questionPairId <= 0) {
        throw Exception('Invalid question pair ID: ${item.questionPairId}');
      }

      final result = await db.insert('upload_queue', item.toMap());
      debugPrint('Successfully added to upload queue with ID: $result');

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

    if (_currentDatabaseName != null) {
      await updateDatabaseStats(_currentDatabaseName!);
    }

    debugPrint('Removed item from upload queue: $queueId');
  }

  Future<void> clearUploadQueue() async {
    await ensureDatabaseConnection();
    final db = await database;
    await db.delete('upload_queue');

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
        uq.tags,
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

  Future<List<QuestionPairWithQueue>> searchQuestionPairs({
    String? query,
    List<String>? tags,
    String? stream,
    String? level,
    String? topic,
  }) async {
    await ensureDatabaseConnection();
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    // Basic text search
    if (query != null && query.isNotEmpty) {
      whereClause += ' AND qp.base_name LIKE ?';
      whereArgs.add('%$query%');
    }

    // Stream filter
    if (stream != null && stream.isNotEmpty) {
      whereClause += ' AND uq.stream = ?';
      whereArgs.add(stream);
    }

    // Level filter
    if (level != null && level.isNotEmpty) {
      whereClause += ' AND uq.level = ?';
      whereArgs.add(level);
    }

    // Topic filter
    if (topic != null && topic.isNotEmpty) {
      whereClause += ' AND uq.topic = ?';
      whereArgs.add(topic);
    }

    // Tags filter - search for any of the provided tags
    if (tags != null && tags.isNotEmpty) {
      final tagConditions = tags.map((_) => 'uq.tags LIKE ?').join(' OR ');
      whereClause += ' AND ($tagConditions)';
      for (final tag in tags) {
        whereArgs.add('%$tag%');
      }
    }

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
        uq.tags,
        uq.created_at as queue_created_at
      FROM question_pairs qp
      LEFT JOIN upload_queue uq ON qp.id = uq.question_pair_id
      WHERE $whereClause
      ORDER BY qp.upload_count ASC, qp.base_name ASC
    ''', whereArgs);

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

  Future<void> cleanupTagUsage() async {
    await ensureDatabaseConnection();
    final db = await database;

    // Remove tags that haven't been used in the last 90 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

    await db.delete(
      'tag_usage',
      where: 'last_used < ? AND usage_count < 2',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    debugPrint('Cleaned up old tag usage data');
  }

  Future<void> cleanupOldRecords() async {
    await ensureDatabaseConnection();
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    await db.delete(
      'question_pairs',
      where: 'last_accessed < ? AND upload_count = 0',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    // Also cleanup PDF cache and tags
    await cleanupPdfCache();
    await cleanupTagUsage(); // ADD THIS LINE

    debugPrint(
        'Cleaned up old unused question pairs, PDF cache, and tag usage');
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

// Updated LocalQuestionPair with PDF support
class LocalQuestionPair {
  final int? id;
  final String baseName;
  final String questionFilePath;
  final String answerFilePath;
  final String questionFileName;
  final String answerFileName;
  final int questionFileSize;
  final int answerFileSize;
  final String? questionPdfPath;
  final String? answerPdfPath;
  final String? questionPdfName;
  final String? answerPdfName;
  final int? questionPdfSize;
  final int? answerPdfSize;
  final DateTime? pdfConvertedAt;
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
    this.questionPdfPath,
    this.answerPdfPath,
    this.questionPdfName,
    this.answerPdfName,
    this.questionPdfSize,
    this.answerPdfSize,
    this.pdfConvertedAt,
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
      'question_pdf_path': questionPdfPath,
      'answer_pdf_path': answerPdfPath,
      'question_pdf_name': questionPdfName,
      'answer_pdf_name': answerPdfName,
      'question_pdf_size': questionPdfSize,
      'answer_pdf_size': answerPdfSize,
      'pdf_converted_at': pdfConvertedAt?.toIso8601String(),
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
      questionPdfPath: map['question_pdf_path']?.toString(),
      answerPdfPath: map['answer_pdf_path']?.toString(),
      questionPdfName: map['question_pdf_name']?.toString(),
      answerPdfName: map['answer_pdf_name']?.toString(),
      questionPdfSize: map['question_pdf_size']?.toInt(),
      answerPdfSize: map['answer_pdf_size']?.toInt(),
      pdfConvertedAt: map['pdf_converted_at'] != null
          ? DateTime.parse(map['pdf_converted_at'])
          : null,
      uploadCount: map['upload_count']?.toInt() ?? 0,
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      lastAccessed: DateTime.parse(
          map['last_accessed'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get hasPdfFiles => questionPdfPath != null && answerPdfPath != null;
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
  final List<String> tags; // ADD THIS FIELD
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
    List<String>? tags, // ADD THIS PARAMETER
    required this.createdAt,
  }) : tags = tags ?? [];

  // MODIFY toMap() method
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
      'tags': tags.join('|'), // Store as pipe-separated string
      'created_at': createdAt.toIso8601String(),
    };
  }

  // MODIFY fromMap() method
  factory UploadQueueItem.fromMap(Map<String, dynamic> map) {
    // Parse tags from pipe-separated string
    final tagsString = map['tags']?.toString() ?? '';
    final tagsList = tagsString.isEmpty
        ? <String>[]
        : tagsString.split('|').where((tag) => tag.isNotEmpty).toList();

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
      tags: tagsList, // ADD THIS LINE
      createdAt: DateTime.parse(map['created_at'] ??
          map['queue_created_at'] ??
          DateTime.now().toIso8601String()),
    );
  }

  // ADD HELPER METHODS
  String get tagsAsString => tags.join(', ');
  bool get hasTags => tags.isNotEmpty;
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
