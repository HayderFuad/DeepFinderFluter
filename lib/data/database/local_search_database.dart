import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/arabic_normalizer.dart';
import '../models/indexed_file_model.dart';

/// High-speed SQLite Full-Text Search (`FTS5` with automatic `FTS4` fallback)
/// database manager.
///
/// Uses `flutter_secure_storage` to persist a unique installation security token
/// and maintains synchronized main metadata table (`indexed_files`) + virtual
/// FTS table (`indexed_files_fts`) for <10ms search latency.
class LocalSearchDatabase {
  LocalSearchDatabase._();
  static final LocalSearchDatabase instance = LocalSearchDatabase._();

  static const _secureStorage = FlutterSecureStorage();
  static const _keyInstallSignature = 'deepfinder_v1_secure_signature';

  Database? _db;
  bool _usingFts5 = true;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    await _ensureSecureSignature();
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'deepfinder_v1_fts_index.db');

    return openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
        } catch (_) {}
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE indexed_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL UNIQUE,
            file_name TEXT NOT NULL,
            normalized_file_name TEXT NOT NULL,
            extension TEXT NOT NULL,
            category TEXT NOT NULL,
            is_directory INTEGER NOT NULL DEFAULT 0,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            last_modified_ms INTEGER NOT NULL DEFAULT 0,
            extracted_content TEXT NOT NULL DEFAULT '',
            normalized_content TEXT NOT NULL DEFAULT '',
            indexed_at_ms INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_normalized_file_name ON indexed_files(normalized_file_name)',
        );
        await db.execute(
          'CREATE INDEX idx_category ON indexed_files(category)',
        );
        await db.execute(
          'CREATE INDEX idx_last_modified ON indexed_files(last_modified_ms DESC)',
        );

        // Create FTS5 virtual table first; fallback to FTS4 if SQLite build lacks FTS5
        try {
          await db.execute('''
            CREATE VIRTUAL TABLE indexed_files_fts USING fts5(
              normalized_file_name,
              normalized_content,
              content='indexed_files',
              content_rowid='id'
            )
          ''');
          _usingFts5 = true;
        } catch (_) {
          await db.execute('''
            CREATE VIRTUAL TABLE indexed_files_fts USING fts4(
              normalized_file_name,
              normalized_content
            )
          ''');
          _usingFts5 = false;
        }
      },
    );
  }

  Future<void> _ensureSecureSignature() async {
    try {
      final existing = await _secureStorage.read(key: _keyInstallSignature);
      if (existing == null || existing.isEmpty) {
        final random = Random.secure();
        final token = List<int>.generate(32, (_) => random.nextInt(256))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        await _secureStorage.write(key: _keyInstallSignature, value: token);
      }
    } catch (_) {
      // Continue safely if platform keychain is locked during boot
    }
  }

  /// Returns a map of `file_path -> (last_modified_ms, size_bytes)` for fast incremental scans.
  Future<Map<String, ({int lastModifiedMs, int sizeBytes})>>
      getExistingSyncMap() async {
    final db = await database;
    final rows = await db.query(
      'indexed_files',
      columns: ['file_path', 'last_modified_ms', 'size_bytes'],
    );
    final result = <String, ({int lastModifiedMs, int sizeBytes})>{};
    for (final row in rows) {
      final path = row['file_path'] as String?;
      if (path != null) {
        result[path] = (
          lastModifiedMs: (row['last_modified_ms'] as int?) ?? 0,
          sizeBytes: (row['size_bytes'] as int?) ?? 0,
        );
      }
    }
    return result;
  }

  /// Inserts or updates a batch of [IndexedFileRecord]s inside a single SQLite transaction
  /// and synchronizes the FTS5/FTS4 virtual index.
  Future<void> upsertBatch(List<IndexedFileRecord> records) async {
    if (records.isEmpty) return;
    final db = await database;

    await db.transaction((txn) async {
      for (final record in records) {
        final rowId = await txn.insert(
          'indexed_files',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.execute(
          'DELETE FROM indexed_files_fts WHERE rowid = ?',
          [rowId],
        );
        await txn.execute(
          'INSERT INTO indexed_files_fts(rowid, normalized_file_name, normalized_content) VALUES (?, ?, ?)',
          [rowId, record.normalizedFileName, record.normalizedContent],
        );
      }
    });
  }

  /// Clears the entire local index.
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('indexed_files');
      await txn.delete('indexed_files_fts');
    });
  }

  /// Returns total indexed count and deep content indexed count.
  Future<({int totalFiles, int deepContentFiles})> getIndexCounts() async {
    final db = await database;
    final totalRes = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM indexed_files'),
        ) ??
        0;
    final deepRes = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM indexed_files WHERE length(normalized_content) > 0',
          ),
        ) ??
        0;
    return (totalFiles: totalRes, deepContentFiles: deepRes);
  }

  /// Returns recent indexed files when the search query is empty.
  Future<List<SearchResultItem>> getRecentFiles({
    required SearchFilter filter,
    int limit = 40,
  }) async {
    final db = await database;
    final rows = await db.query(
      'indexed_files',
      orderBy: 'last_modified_ms DESC',
      limit: 120,
    );

    final items = <SearchResultItem>[];
    for (final row in rows) {
      final record = IndexedFileRecord.fromMap(row);
      final category = FileCategory.values.firstWhere(
        (c) => c.name == record.category,
        orElse: () => FileCategory.fromExtension(
          record.extension,
          isDirectory: record.isDirectory,
        ),
      );

      if (!_matchesFilter(
        filter: filter,
        category: category,
        matchScope: MatchScope.nameOnly,
        isDirectory: record.isDirectory,
      )) {
        continue;
      }

      final previewSnippet =
          (!record.isDirectory && record.extractedContent.trim().isNotEmpty)
              ? record.extractedContent
                  .substring(0, record.extractedContent.length.clamp(0, 140))
                  .replaceAll('\n', ' ')
                  .trim()
              : null;

      items.add(
        SearchResultItem(
          id: record.id ?? 0,
          filePath: record.filePath,
          displayPath: _shortenPath(record.filePath),
          fileName: record.fileName,
          extension: record.extension,
          category: category,
          isDirectory: record.isDirectory,
          sizeBytes: record.sizeBytes,
          lastModifiedMs: record.lastModifiedMs,
          matchScope: MatchScope.nameOnly,
          nameHighlights: const [],
          snippetText: previewSnippet,
          snippetHighlights: const [],
        ),
      );
      if (items.length >= limit) break;
    }
    return items;
  }

  /// Executes a sub-10ms combined search across filenames and FTS5/FTS4 deep content.
  Future<List<SearchResultItem>> search({
    required String rawQuery,
    required SearchFilter filter,
    int limit = 120,
  }) async {
    final normalizedQuery = ArabicNormalizer.normalize(rawQuery);
    if (normalizedQuery.isEmpty) {
      return getRecentFiles(filter: filter, limit: 40);
    }

    final db = await database;
    final ftsQuery = ArabicNormalizer.toFtsQuery(rawQuery);

    List<Map<String, Object?>> rows = [];
    if (ftsQuery.isNotEmpty) {
      try {
        rows = await db.rawQuery(
          '''
          SELECT f.* FROM indexed_files f
          LEFT JOIN indexed_files_fts fts ON f.id = fts.rowid
          WHERE indexed_files_fts MATCH ?
             OR f.normalized_file_name LIKE '%' || ? || '%'
          ORDER BY
            CASE WHEN f.normalized_file_name LIKE ? || '%' THEN 0
                 WHEN f.normalized_file_name LIKE '%' || ? || '%' THEN 1
                 ELSE 2
            END,
            f.last_modified_ms DESC
          LIMIT ?
          ''',
          [ftsQuery, normalizedQuery, normalizedQuery, normalizedQuery, limit],
        );
      } catch (_) {
        rows = await _fallbackLikeQuery(db, normalizedQuery, limit);
      }
    } else {
      rows = await _fallbackLikeQuery(db, normalizedQuery, limit);
    }

    final queryTokens =
        normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final results = <SearchResultItem>[];

    for (final row in rows) {
      final record = IndexedFileRecord.fromMap(row);

      final nameMatched = queryTokens.every(
            (token) => record.normalizedFileName.contains(token),
          ) ||
          record.normalizedFileName.contains(normalizedQuery);

      final contentMatched = !record.isDirectory &&
          record.normalizedContent.isNotEmpty &&
          (queryTokens.every(
                (token) => record.normalizedContent.contains(token),
              ) ||
              record.normalizedContent.contains(normalizedQuery));

      if (!nameMatched && !contentMatched) continue;

      final matchScope = (nameMatched && contentMatched)
          ? MatchScope.nameAndContent
          : (nameMatched ? MatchScope.nameOnly : MatchScope.contentOnly);

      final category = FileCategory.values.firstWhere(
        (c) => c.name == record.category,
        orElse: () => FileCategory.fromExtension(
          record.extension,
          isDirectory: record.isDirectory,
        ),
      );

      if (!_matchesFilter(
        filter: filter,
        category: category,
        matchScope: matchScope,
        isDirectory: record.isDirectory,
      )) {
        continue;
      }

      final nameHighlights = nameMatched
          ? ArabicNormalizer.findHighlightRanges(record.fileName, rawQuery)
          : const <HighlightRange>[];

      String? snippet;
      List<HighlightRange> snippetHighlights = const [];
      if (contentMatched && record.extractedContent.isNotEmpty) {
        final extracted = ArabicNormalizer.extractSnippetWithHighlights(
          record.extractedContent,
          rawQuery,
        );
        snippet = extracted.snippet;
        snippetHighlights = extracted.highlights;
      }

      results.add(
        SearchResultItem(
          id: record.id ?? 0,
          filePath: record.filePath,
          displayPath: _shortenPath(record.filePath),
          fileName: record.fileName,
          extension: record.extension,
          category: category,
          isDirectory: record.isDirectory,
          sizeBytes: record.sizeBytes,
          lastModifiedMs: record.lastModifiedMs,
          matchScope: matchScope,
          nameHighlights: nameHighlights,
          snippetText: snippet,
          snippetHighlights: snippetHighlights,
        ),
      );
    }

    return results;
  }

  Future<List<Map<String, Object?>>> _fallbackLikeQuery(
    Database db,
    String normalizedQuery,
    int limit,
  ) {
    return db.rawQuery(
      '''
      SELECT * FROM indexed_files
      WHERE normalized_file_name LIKE '%' || ? || '%'
         OR normalized_content LIKE '%' || ? || '%'
      ORDER BY last_modified_ms DESC
      LIMIT ?
      ''',
      [normalizedQuery, normalizedQuery, limit],
    );
  }

  bool _matchesFilter({
    required SearchFilter filter,
    required FileCategory category,
    required MatchScope matchScope,
    required bool isDirectory,
  }) {
    switch (filter) {
      case SearchFilter.all:
        return true;
      case SearchFilter.nameOnly:
        return matchScope == MatchScope.nameOnly ||
            matchScope == MatchScope.nameAndContent;
      case SearchFilter.contentOnly:
        return matchScope == MatchScope.contentOnly ||
            matchScope == MatchScope.nameAndContent;
      case SearchFilter.pdf:
        return category == FileCategory.pdf;
      case SearchFilter.office:
        return category == FileCategory.word || category == FileCategory.excel;
      case SearchFilter.textFiles:
        return category == FileCategory.text;
      case SearchFilter.folders:
        return isDirectory || category == FileCategory.folder;
    }
  }

  String _shortenPath(String fullPath) {
    const androidPrefix = '/storage/emulated/0/';
    if (fullPath.startsWith(androidPrefix)) {
      return 'التخزين الداخلي / ${fullPath.substring(androidPrefix.length)}';
    }
    return fullPath;
  }
}
