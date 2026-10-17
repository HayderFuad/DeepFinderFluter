import '../../core/utils/arabic_normalizer.dart';

/// Categories of files supported by DeepFinder v1.
enum FileCategory {
  folder('مجلد'),
  pdf('PDF'),
  word('Word'),
  excel('Excel'),
  text('ملف نصي'),
  other('ملف');

  final String labelAr;
  const FileCategory(this.labelAr);

  static FileCategory fromExtension(String ext, {required bool isDirectory}) {
    if (isDirectory) return FileCategory.folder;
    switch (ext.toLowerCase()) {
      case 'pdf':
        return FileCategory.pdf;
      case 'docx':
      case 'doc':
        return FileCategory.word;
      case 'xlsx':
      case 'xls':
        return FileCategory.excel;
      case 'txt':
      case 'md':
      case 'json':
      case 'csv':
      case 'xml':
      case 'log':
        return FileCategory.text;
      default:
        return FileCategory.other;
    }
  }
}

/// Filter chips displayed in the main search screen.
enum SearchFilter {
  all('الكل'),
  nameOnly('بالاسم'),
  contentOnly('بالمحتوى'),
  pdf('PDF'),
  office('Word/Excel'),
  textFiles('نصوص'),
  folders('مجلدات');

  final String labelAr;
  const SearchFilter(this.labelAr);
}

/// Indicates whether a search hit matched the filename, deep content, or both.
enum MatchScope {
  nameAndContent('تطابق الاسم والمحتوى'),
  nameOnly('تطابق الاسم'),
  contentOnly('تطابق المحتوى العميق');

  final String badgeAr;
  const MatchScope(this.badgeAr);
}

/// Database record representing an indexed file or directory.
class IndexedFileRecord {
  final int? id;
  final String filePath;
  final String fileName;
  final String normalizedFileName;
  final String extension;
  final String category;
  final bool isDirectory;
  final int sizeBytes;
  final int lastModifiedMs;
  final String extractedContent;
  final String normalizedContent;
  final int indexedAtMs;

  const IndexedFileRecord({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.normalizedFileName,
    required this.extension,
    required this.category,
    required this.isDirectory,
    required this.sizeBytes,
    required this.lastModifiedMs,
    required this.extractedContent,
    required this.normalizedContent,
    required this.indexedAtMs,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'normalized_file_name': normalizedFileName,
      'extension': extension,
      'category': category,
      'is_directory': isDirectory ? 1 : 0,
      'size_bytes': sizeBytes,
      'last_modified_ms': lastModifiedMs,
      'extracted_content': extractedContent,
      'normalized_content': normalizedContent,
      'indexed_at_ms': indexedAtMs,
    };
  }

  factory IndexedFileRecord.fromMap(Map<String, Object?> map) {
    return IndexedFileRecord(
      id: map['id'] as int?,
      filePath: (map['file_path'] as String?) ?? '',
      fileName: (map['file_name'] as String?) ?? '',
      normalizedFileName: (map['normalized_file_name'] as String?) ?? '',
      extension: (map['extension'] as String?) ?? '',
      category: (map['category'] as String?) ?? FileCategory.other.name,
      isDirectory: ((map['is_directory'] as int?) ?? 0) == 1,
      sizeBytes: (map['size_bytes'] as int?) ?? 0,
      lastModifiedMs: (map['last_modified_ms'] as int?) ?? 0,
      extractedContent: (map['extracted_content'] as String?) ?? '',
      normalizedContent: (map['normalized_content'] as String?) ?? '',
      indexedAtMs: (map['indexed_at_ms'] as int?) ?? 0,
    );
  }
}

/// UI presentation model for a single search result card.
class SearchResultItem {
  final int id;
  final String filePath;
  final String displayPath;
  final String fileName;
  final String extension;
  final FileCategory category;
  final bool isDirectory;
  final int sizeBytes;
  final int lastModifiedMs;
  final MatchScope matchScope;
  final List<HighlightRange> nameHighlights;
  final String? snippetText;
  final List<HighlightRange> snippetHighlights;

  const SearchResultItem({
    required this.id,
    required this.filePath,
    required this.displayPath,
    required this.fileName,
    required this.extension,
    required this.category,
    required this.isDirectory,
    required this.sizeBytes,
    required this.lastModifiedMs,
    required this.matchScope,
    required this.nameHighlights,
    this.snippetText,
    required this.snippetHighlights,
  });
}
