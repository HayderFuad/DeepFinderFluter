import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/local_search_database.dart';
import '../../data/models/indexed_file_model.dart';
import '../../data/parsers/isolate_document_parser.dart';

/// Immutable state holding search results, active filters, and live indexing progress.
class SearchIndexState {
  final String query;
  final SearchFilter selectedFilter;
  final List<SearchResultItem> results;
  final double searchLatencyMs;
  final bool isIndexing;
  final int indexedCount;
  final int totalEstimatedCount;
  final String currentIndexingFile;
  final int totalFilesInDb;
  final int deepFilesInDb;
  final List<String> indexedRoots;
  final bool hasShownDisclosure;
  final String? statusMessage;

  const SearchIndexState({
    this.query = '',
    this.selectedFilter = SearchFilter.all,
    this.results = const [],
    this.searchLatencyMs = 0.0,
    this.isIndexing = false,
    this.indexedCount = 0,
    this.totalEstimatedCount = 0,
    this.currentIndexingFile = '',
    this.totalFilesInDb = 0,
    this.deepFilesInDb = 0,
    this.indexedRoots = const [],
    this.hasShownDisclosure = false,
    this.statusMessage,
  });

  double get progressFraction {
    if (!isIndexing || totalEstimatedCount <= 0) return 0.0;
    return (indexedCount / totalEstimatedCount).clamp(0.0, 1.0);
  }

  SearchIndexState copyWith({
    String? query,
    SearchFilter? selectedFilter,
    List<SearchResultItem>? results,
    double? searchLatencyMs,
    bool? isIndexing,
    int? indexedCount,
    int? totalEstimatedCount,
    String? currentIndexingFile,
    int? totalFilesInDb,
    int? deepFilesInDb,
    List<String>? indexedRoots,
    bool? hasShownDisclosure,
    String? statusMessage,
  }) {
    return SearchIndexState(
      query: query ?? this.query,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      results: results ?? this.results,
      searchLatencyMs: searchLatencyMs ?? this.searchLatencyMs,
      isIndexing: isIndexing ?? this.isIndexing,
      indexedCount: indexedCount ?? this.indexedCount,
      totalEstimatedCount: totalEstimatedCount ?? this.totalEstimatedCount,
      currentIndexingFile: currentIndexingFile ?? this.currentIndexingFile,
      totalFilesInDb: totalFilesInDb ?? this.totalFilesInDb,
      deepFilesInDb: deepFilesInDb ?? this.deepFilesInDb,
      indexedRoots: indexedRoots ?? this.indexedRoots,
      hasShownDisclosure: hasShownDisclosure ?? this.hasShownDisclosure,
      statusMessage: statusMessage,
    );
  }
}

final searchIndexProvider =
    StateNotifierProvider<SearchIndexNotifier, SearchIndexState>((ref) {
  return SearchIndexNotifier();
});

class SearchIndexNotifier extends StateNotifier<SearchIndexState> {
  static const String _prefsRootsKey = 'deepfinder_v1_indexed_roots';
  static const String _prefsDisclosureKey = 'deepfinder_v1_disclosure_accepted';

  static const int _fastMetadataBatchSize = 150;
  static const int _deepParseBatchSize = 8;

  Timer? _debounceTimer;
  bool _cancelRequested = false;
  final LocalSearchDatabase _db = LocalSearchDatabase.instance;

  SearchIndexNotifier() : super(const SearchIndexState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoots = prefs.getStringList(_prefsRootsKey) ?? <String>[];
    final disclosureAccepted = prefs.getBool(_prefsDisclosureKey) ?? false;
    final counts = await _db.getIndexCounts();
    final initialResults = await _db.getRecentFiles(filter: SearchFilter.all);

    state = state.copyWith(
      indexedRoots: savedRoots,
      hasShownDisclosure: disclosureAccepted,
      totalFilesInDb: counts.totalFiles,
      deepFilesInDb: counts.deepContentFiles,
      results: initialResults,
    );
  }

  Future<void> markDisclosureAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsDisclosureKey, true);
    state = state.copyWith(hasShownDisclosure: true);
  }

  /// Allows the user to stop an ongoing scan immediately without losing already-indexed files.
  void cancelIndexing() {
    if (state.isIndexing) {
      _cancelRequested = true;
    }
  }

  /// Debounced real-time instant search (300ms).
  void onQueryChanged(String newQuery) {
    state = state.copyWith(query: newQuery);
    _debounceTimer?.cancel();

    if (newQuery.trim().isEmpty) {
      _executeSearch(newQuery, state.selectedFilter);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(newQuery, state.selectedFilter);
    });
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    state = state.copyWith(query: '');
    _executeSearch('', state.selectedFilter);
  }

  void selectFilter(SearchFilter filter) {
    state = state.copyWith(selectedFilter: filter);
    _executeSearch(state.query, filter);
  }

  Future<void> _executeSearch(String query, SearchFilter filter) async {
    final stopwatch = Stopwatch()..start();
    final matched = await _db.search(rawQuery: query, filter: filter);
    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

    state = state.copyWith(
      results: matched,
      searchLatencyMs: elapsedMs,
    );
  }

  /// Method 1: Safe Folder Picker (SAF / iOS Document Picker).
  Future<void> pickDirectoryAndIndex() async {
    if (state.isIndexing) return;

    try {
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلداً لفهرسته والبحث بداخله',
      );

      if (selectedDir != null && selectedDir.isNotEmpty) {
        final updatedRoots = <String>{...state.indexedRoots, selectedDir}.toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_prefsRootsKey, updatedRoots);
        state = state.copyWith(indexedRoots: updatedRoots);
        await _indexDirectories([selectedDir]);
        return;
      }

      if (Platform.isIOS) {
        final pickedFiles = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          withData: false,
        );
        if (pickedFiles != null && pickedFiles.files.isNotEmpty) {
          final paths = pickedFiles.files
              .map((f) => f.path)
              .whereType<String>()
              .toList();
          await _indexSpecificFilePaths(paths);
        }
      }
    } catch (e) {
      state = state.copyWith(
        statusMessage: 'تعذر فتح محدد المجلدات: $e',
      );
    }
  }

  /// Method 2: Smart Full Phone Scan (Prioritizes user document directories first,
  /// then non-media folders on `/storage/emulated/0` inside a background Isolate).
  Future<void> requestFullStorageAndIndex() async {
    if (state.isIndexing) return;

    if (Platform.isIOS) {
      await pickDirectoryAndIndex();
      return;
    }

    bool granted = false;
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      granted = true;
    } else {
      final reqManage = await Permission.manageExternalStorage.request();
      if (reqManage.isGranted) {
        granted = true;
      } else {
        final reqStorage = await Permission.storage.request();
        granted = reqStorage.isGranted;
      }
    }

    if (!granted) {
      state = state.copyWith(
        statusMessage:
            'لم يتم منح صلاحية الوصول الشامل. يمكنك استخدام «إضافة مجلد للفهرسة» للبحث الآمن.',
      );
      return;
    }

    // Prioritize high-value document folders first before scanning general root
    final priorityRoots = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Books',
      '/storage/emulated/0/Notes',
      '/storage/emulated/0',
    ];

    final updatedRoots = <String>{...state.indexedRoots, '/storage/emulated/0'}.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsRootsKey, updatedRoots);
    state = state.copyWith(indexedRoots: updatedRoots);

    await _indexDirectories(priorityRoots);
  }

  Future<void> refreshIndex({bool forceRebuild = false}) async {
    if (state.isIndexing) return;
    if (forceRebuild) {
      await _db.clearAll();
    }
    if (state.indexedRoots.isEmpty) {
      await pickDirectoryAndIndex();
      return;
    }
    await _indexDirectories(state.indexedRoots, forceRebuild: forceRebuild);
  }

  /// Two-Phase Non-Blocking Indexing Pipeline:
  /// - Phase 0: Discover files inside a background Isolate (zero main-thread lag).
  /// - Phase 1: Index all file/folder names in fast batches of 150 (instant name search).
  /// - Phase 2: Parse deep document content (`PDF, DOCX, XLSX, TXT...`) in small batches of 8
  ///   with UI frame breathers so the app never freezes or runs out of memory.
  Future<void> _indexDirectories(
    List<String> rootPaths, {
    bool forceRebuild = false,
  }) async {
    _cancelRequested = false;
    state = state.copyWith(
      isIndexing: true,
      indexedCount: 0,
      totalEstimatedCount: 0,
      currentIndexingFile: 'جاري استكشاف الملفات في الخلفية…',
    );

    try {
      final existingSyncMap = await _db.getExistingSyncMap();

      // Phase 0: Background Isolate file discovery (Zero UI Freeze)
      final discovered = await IsolateDocumentParser.discoverFilesInIsolate(
        DirectoryScanRequest(
          rootPaths: rootPaths,
          existingSyncMap: existingSyncMap,
          forceRebuild: forceRebuild,
        ),
      );

      if (discovered.isEmpty || _cancelRequested) {
        final counts = await _db.getIndexCounts();
        state = state.copyWith(
          isIndexing: false,
          indexedCount: counts.totalFiles,
          totalEstimatedCount: counts.totalFiles,
          currentIndexingFile: '',
          totalFilesInDb: counts.totalFiles,
          deepFilesInDb: counts.deepContentFiles,
        );
        await _executeSearch(state.query, state.selectedFilter);
        return;
      }

      final metadataOnlyItems =
          discovered.where((d) => !d.needsDeepParse).toList();
      final deepParseItems =
          discovered.where((d) => d.needsDeepParse).toList();

      final totalWork = discovered.length;
      int completedWork = 0;

      state = state.copyWith(
        totalEstimatedCount: totalWork,
        indexedCount: 0,
        currentIndexingFile: 'المرحلة 1/2: فهرسة سريعة للأسماء والمجلدات…',
      );

      // Phase 1: Fast Metadata Indexing (150 items per batch)
      for (int i = 0; i < metadataOnlyItems.length; i += _fastMetadataBatchSize) {
        if (_cancelRequested) break;
        final end = (i + _fastMetadataBatchSize).clamp(0, metadataOnlyItems.length);
        final batch = metadataOnlyItems.sublist(i, end);

        final records =
            await IsolateDocumentParser.buildMetadataBatchInIsolate(batch);
        await _db.upsertBatch(records);

        completedWork += batch.length;
        state = state.copyWith(
          indexedCount: completedWork,
          currentIndexingFile: 'فهرسة الأسماء: ${p.basename(batch.last.path)}',
        );

        // Yield 8ms to keep UI animations & scrolling at 60/120 FPS
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }

      // Refresh search results right after Phase 1 so name matches appear immediately!
      final midCounts = await _db.getIndexCounts();
      state = state.copyWith(
        totalFilesInDb: midCounts.totalFiles,
        deepFilesInDb: midCounts.deepContentFiles,
      );
      await _executeSearch(state.query, state.selectedFilter);

      // Phase 2: Throttled Deep Document Content Indexing (8 documents per batch)
      for (int i = 0; i < deepParseItems.length; i += _deepParseBatchSize) {
        if (_cancelRequested) break;
        final end = (i + _deepParseBatchSize).clamp(0, deepParseItems.length);
        final batch = deepParseItems.sublist(i, end);

        state = state.copyWith(
          currentIndexingFile:
              'المرحلة 2/2 (محتوى عميق): ${p.basename(batch.last.path)}',
        );

        final parsedRecords =
            await IsolateDocumentParser.parseDeepBatchInIsolate(batch);
        await _db.upsertBatch(parsedRecords);

        completedWork += batch.length;
        final counts = await _db.getIndexCounts();
        state = state.copyWith(
          indexedCount: completedWork,
          totalFilesInDb: counts.totalFiles,
          deepFilesInDb: counts.deepContentFiles,
        );

        // Give Dart GC and UI thread a 15ms breather between heavy PDF/DOCX batches
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
    } catch (e) {
      state = state.copyWith(
        statusMessage: 'تم إكمال الفهرسة الآمنة مع تجاوز بعض الملفات المحمية.',
      );
    } finally {
      final finalCounts = await _db.getIndexCounts();
      state = state.copyWith(
        isIndexing: false,
        currentIndexingFile: '',
        totalFilesInDb: finalCounts.totalFiles,
        deepFilesInDb: finalCounts.deepContentFiles,
      );
      await _executeSearch(state.query, state.selectedFilter);
    }
  }

  Future<void> _indexSpecificFilePaths(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    _cancelRequested = false;
    state = state.copyWith(
      isIndexing: true,
      indexedCount: 0,
      totalEstimatedCount: filePaths.length,
      currentIndexingFile: 'جاري فهرسة الملفات المختارة…',
    );

    try {
      final descriptors = <FileParseDescriptor>[];
      for (final path in filePaths) {
        try {
          final stat = File(path).statSync();
          descriptors.add(
            FileParseDescriptor(
              path: path,
              isDirectory: false,
              sizeBytes: stat.size,
              lastModifiedMs: stat.modified.millisecondsSinceEpoch,
              needsDeepParse: true,
            ),
          );
        } catch (_) {}
      }

      for (int i = 0; i < descriptors.length; i += _deepParseBatchSize) {
        if (_cancelRequested) break;
        final end = (i + _deepParseBatchSize).clamp(0, descriptors.length);
        final batch = descriptors.sublist(i, end);
        final parsedRecords =
            await IsolateDocumentParser.parseDeepBatchInIsolate(batch);
        await _db.upsertBatch(parsedRecords);
        state = state.copyWith(indexedCount: end);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      final counts = await _db.getIndexCounts();
      state = state.copyWith(
        isIndexing: false,
        currentIndexingFile: '',
        totalFilesInDb: counts.totalFiles,
        deepFilesInDb: counts.deepContentFiles,
      );
      await _executeSearch(state.query, state.selectedFilter);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
