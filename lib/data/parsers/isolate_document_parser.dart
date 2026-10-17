import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../models/indexed_file_model.dart';

/// Input descriptor for a discovered file or folder.
class FileParseDescriptor {
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final int lastModifiedMs;
  final bool needsDeepParse;

  const FileParseDescriptor({
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
    required this.lastModifiedMs,
    required this.needsDeepParse,
  });
}

/// Request payload sent to the background directory-discovery Isolate.
class DirectoryScanRequest {
  final List<String> rootPaths;
  final Map<String, ({int lastModifiedMs, int sizeBytes})> existingSyncMap;
  final bool forceRebuild;
  final int maxFilesLimit;

  const DirectoryScanRequest({
    required this.rootPaths,
    required this.existingSyncMap,
    required this.forceRebuild,
    this.maxFilesLimit = 12000,
  });
}

/// High-speed, low-memory background crawler and document parser executed inside
/// `Isolate.run(...)` to prevent UI freezes (ANR) and OutOfMemory crashes.
class IsolateDocumentParser {
  IsolateDocumentParser._();

  /// Cap stored text per file at 15,000 chars (~25 KB) so Android SQLite
  /// CursorWindow (2 MB limit) never overflows and RAM stays featherlight.
  static const int maxExtractedChars = 15000;

  /// Strict size limits per format for deep content extraction.
  static const int maxPlainTextSizeBytes = 2 * 1024 * 1024; // 2 MB
  static const int maxOfficeSizeBytes = 8 * 1024 * 1024; // 8 MB
  static const int maxPdfSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxPdfPagesToRead = 25;

  /// Phase 0: Crawls directory trees inside a background Dart Isolate!
  /// Zero `listSync()` or `statSync()` calls ever happen on the main UI thread.
  static Future<List<FileParseDescriptor>> discoverFilesInIsolate(
    DirectoryScanRequest request,
  ) async {
    return Isolate.run(() {
      final results = <FileParseDescriptor>[];
      final queue = Queue<({Directory dir, int depth})>();
      final seenPaths = <String>{};

      for (final rootPath in request.rootPaths) {
        final dir = Directory(rootPath);
        if (dir.existsSync()) {
          queue.add((dir: dir, depth: 0));
        }
      }

      while (queue.isNotEmpty && results.length < request.maxFilesLimit) {
        final current = queue.removeFirst();
        if (current.depth > 8) continue;

        List<FileSystemEntity> entities;
        try {
          entities = current.dir.listSync(followLinks: false);
        } catch (_) {
          continue;
        }

        for (final entity in entities) {
          if (results.length >= request.maxFilesLimit) break;
          final fullPath = entity.path;
          if (!seenPaths.add(fullPath)) continue;

          final name = p.basename(fullPath);
          if (_shouldSkipPath(fullPath, name)) continue;

          try {
            final stat = entity.statSync();
            final isDir = stat.type == FileSystemEntityType.directory;
            final lastModMs = stat.modified.millisecondsSinceEpoch;
            final size = isDir ? 0 : stat.size;

            if (isDir) {
              queue.add((dir: Directory(fullPath), depth: current.depth + 1));
            }

            final existing = request.existingSyncMap[fullPath];
            final unchanged = !request.forceRebuild &&
                existing != null &&
                existing.lastModifiedMs == lastModMs &&
                existing.sizeBytes == size;

            if (!unchanged) {
              final ext = isDir
                  ? ''
                  : p.extension(fullPath).replaceFirst('.', '').toLowerCase();
              final eligibleForDeep = !isDir && _isEligibleForDeepParse(ext, size);

              results.add(
                FileParseDescriptor(
                  path: fullPath,
                  isDirectory: isDir,
                  sizeBytes: size,
                  lastModifiedMs: lastModMs,
                  needsDeepParse: eligibleForDeep,
                ),
              );
            }
          } catch (_) {
            continue;
          }
        }
      }

      return results;
    });
  }

  /// Phase 1: Ultra-fast metadata-only batch builder (no heavy file I/O)
  /// so filenames and folders become searchable within 1-2 seconds.
  static Future<List<IndexedFileRecord>> buildMetadataBatchInIsolate(
    List<FileParseDescriptor> batch,
  ) async {
    return Isolate.run(() {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      return batch.map((item) {
        final name = p.basename(item.path);
        final ext = item.isDirectory
            ? ''
            : p.extension(item.path).replaceFirst('.', '').toLowerCase();
        final category = FileCategory.fromExtension(
          ext,
          isDirectory: item.isDirectory,
        );
        return IndexedFileRecord(
          filePath: item.path,
          fileName: name,
          normalizedFileName: ArabicNormalizer.normalize(name),
          extension: ext,
          category: category.name,
          isDirectory: item.isDirectory,
          sizeBytes: item.sizeBytes,
          lastModifiedMs: item.lastModifiedMs,
          extractedContent: '',
          normalizedContent: '',
          indexedAtMs: nowMs,
        );
      }).toList();
    });
  }

  /// Phase 2: Parses deep document text in small memory-safe batches inside an Isolate.
  static Future<List<IndexedFileRecord>> parseDeepBatchInIsolate(
    List<FileParseDescriptor> batch,
  ) async {
    return Isolate.run(() {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final results = <IndexedFileRecord>[];

      for (final item in batch) {
        final name = p.basename(item.path);
        final ext = item.isDirectory
            ? ''
            : p.extension(item.path).replaceFirst('.', '').toLowerCase();
        final category = FileCategory.fromExtension(
          ext,
          isDirectory: item.isDirectory,
        );

        String extractedContent = '';
        if (!item.isDirectory && _isEligibleForDeepParse(ext, item.sizeBytes)) {
          extractedContent = _extractFileTextSafe(item.path, ext, item.sizeBytes);
        }

        final normalizedName = ArabicNormalizer.normalize(name);
        final normalizedBody = extractedContent.isNotEmpty
            ? ArabicNormalizer.normalize(extractedContent)
            : '';

        results.add(
          IndexedFileRecord(
            filePath: item.path,
            fileName: name,
            normalizedFileName: normalizedName,
            extension: ext,
            category: category.name,
            isDirectory: item.isDirectory,
            sizeBytes: item.sizeBytes,
            lastModifiedMs: item.lastModifiedMs,
            extractedContent: extractedContent,
            normalizedContent: normalizedBody,
            indexedAtMs: nowMs,
          ),
        );
      }

      return results;
    });
  }

  static bool _isEligibleForDeepParse(String ext, int sizeBytes) {
    if (sizeBytes <= 0) return false;
    if (!AppConstants.supportedDeepExtensions.contains(ext)) return false;
    switch (ext) {
      case 'txt':
      case 'md':
      case 'json':
      case 'csv':
      case 'xml':
      case 'log':
        return sizeBytes <= maxPlainTextSizeBytes;
      case 'docx':
      case 'xlsx':
        return sizeBytes <= maxOfficeSizeBytes;
      case 'pdf':
        return sizeBytes <= maxPdfSizeBytes;
      default:
        return false;
    }
  }

  static bool _shouldSkipPath(String fullPath, String baseName) {
    if (baseName.isEmpty || baseName.startsWith('.')) return true;
    final lowerPath = fullPath.toLowerCase().replaceAll('\\', '/');
    for (final excluded in AppConstants.defaultExcludedFolders) {
      final pattern = excluded.toLowerCase();
      if (baseName.toLowerCase() == pattern ||
          lowerPath.contains('/$pattern/') ||
          lowerPath.endsWith('/$pattern')) {
        return true;
      }
    }
    return false;
  }

  static String _extractFileTextSafe(String filePath, String ext, int sizeBytes) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '';

      switch (ext) {
        case 'txt':
        case 'md':
        case 'json':
        case 'csv':
        case 'xml':
        case 'log':
          return _extractPlainTextHead(file, sizeBytes);
        case 'pdf':
          return _extractPdfTextBounded(file);
        case 'docx':
          return _extractDocxTextBounded(file);
        case 'xlsx':
          return _extractXlsxTextBounded(file);
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  /// Reads only the first 36 KB of a plain text file using RandomAccessFile
  /// instead of loading the entire multi-megabyte file into memory.
  static String _extractPlainTextHead(File file, int sizeBytes) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final bytesToRead = sizeBytes < 36864 ? sizeBytes : 36864;
      final chunk = raf.readSync(bytesToRead);
      final decoded = utf8.decode(chunk, allowMalformed: true);
      return decoded.length > maxExtractedChars
          ? decoded.substring(0, maxExtractedChars)
          : decoded;
    } finally {
      raf.closeSync();
    }
  }

  static String _extractPdfTextBounded(File file) {
    final bytes = file.readAsBytesSync();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      final pageLimit = document.pages.count < maxPdfPagesToRead
          ? document.pages.count
          : maxPdfPagesToRead;

      for (int i = 0; i < pageLimit; i++) {
        if (buffer.length >= maxExtractedChars) break;
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (pageText.isNotEmpty) {
          final remaining = maxExtractedChars - buffer.length;
          if (pageText.length > remaining) {
            buffer.write(pageText.substring(0, remaining));
          } else {
            buffer.write(pageText);
            buffer.write(' ');
          }
        }
      }
      return buffer.toString().trim();
    } finally {
      document.dispose();
    }
  }

  static String _extractDocxTextBounded(File file) {
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final buffer = StringBuffer();

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'word/document.xml') {
        final contentBytes = entry.content as List<int>;
        if (contentBytes.length > 2 * 1024 * 1024) break;
        final xmlString = utf8.decode(contentBytes, allowMalformed: true);
        final document = XmlDocument.parse(xmlString);

        for (final node in document.descendants.whereType<XmlElement>()) {
          if (node.name.local == 't') {
            final text = node.innerText;
            if (text.isNotEmpty) {
              buffer.write(text);
              buffer.write(' ');
              if (buffer.length >= maxExtractedChars) break;
            }
          }
        }
        break;
      }
    }

    final result = buffer.toString().trim();
    return result.length > maxExtractedChars
        ? result.substring(0, maxExtractedChars)
        : result;
  }

  static String _extractXlsxTextBounded(File file) {
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final buffer = StringBuffer();

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'xl/sharedStrings.xml' ||
          name == 'xl/worksheets/sheet1.xml') {
        final contentBytes = entry.content as List<int>;
        if (contentBytes.length > 2 * 1024 * 1024) continue;
        final xmlString = utf8.decode(contentBytes, allowMalformed: true);
        final document = XmlDocument.parse(xmlString);

        for (final node in document.descendants.whereType<XmlElement>()) {
          if (node.name.local == 't' || node.name.local == 'v') {
            final text = node.innerText.trim();
            if (text.isNotEmpty) {
              buffer.write(text);
              buffer.write(' ');
              if (buffer.length >= maxExtractedChars) break;
            }
          }
        }
      }
      if (buffer.length >= maxExtractedChars) break;
    }

    final result = buffer.toString().trim();
    return result.length > maxExtractedChars
        ? result.substring(0, maxExtractedChars)
        : result;
  }
}
