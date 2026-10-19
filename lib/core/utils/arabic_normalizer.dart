/// Range of character offsets in an original un-normalized string.
class HighlightRange {
  final int start;
  final int end;

  const HighlightRange({required this.start, required this.end});
}

/// Internal mapping between normalized text and its source character indices.
class NormalizedMapping {
  final String normalizedText;
  final List<int> originalIndices;

  const NormalizedMapping({
    required this.normalizedText,
    required this.originalIndices,
  });
}

/// Contextual snippet result with pre-computed highlight ranges.
class SnippetExtractionResult {
  final String snippet;
  final List<HighlightRange> highlights;

  const SnippetExtractionResult({
    required this.snippet,
    required this.highlights,
  });
}

/// Smart Arabic & Multilingual Text Normalizer.
///
/// Unifies orthographic variations before saving to FTS5 and when querying:
/// - Hamzas: (أ، إ، آ، ٱ) -> ا
/// - Ta Marbuta: (ة) -> ه
/// - Alef Maqsura & Farsi Yeh: (ى، ی، ئ) -> ي
/// - Waw with Hamza: (ؤ) -> و
/// - Strips Arabic Diacritics (Tashkeel / Harakat) and Tatweel (ـ)
/// - Lowercases Latin characters
///
/// Preserves exact character index mapping so `RichText` / `TextSpan` highlights
/// the exact words in the original text even when diacritics or Hamzas differ.
class ArabicNormalizer {
  ArabicNormalizer._();

  static final RegExp _multiSpaceRegex = RegExp(r'\s+');

  /// Fast normalization for database indexing and query preparation.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final mapped = _normalizeChar(input.codeUnitAt(i));
      if (mapped != 0) {
        buffer.writeCharCode(mapped);
      }
    }
    return buffer.toString().replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Builds an SQLite FTS5 / FTS4 prefix token query.
  /// Example: "إبراهيم أحمد" -> '"ابراهيم"* "احمد"*'
  static String toFtsQuery(String rawQuery) {
    final normalized = normalize(rawQuery);
    if (normalized.isEmpty) return '';
    final tokens = normalized
        .split(' ')
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}_]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }

  /// Normalizes [original] while recording the source character index of every
  /// character in the normalized output.
  static NormalizedMapping normalizeWithMapping(String original) {
    if (original.isEmpty) {
      return const NormalizedMapping(normalizedText: '', originalIndices: []);
    }
    final charCodes = <int>[];
    final indices = <int>[];

    for (int i = 0; i < original.length; i++) {
      final mapped = _normalizeChar(original.codeUnitAt(i));
      if (mapped != 0) {
        charCodes.add(mapped);
        indices.add(i);
      }
    }

    return NormalizedMapping(
      normalizedText: String.fromCharCodes(charCodes),
      originalIndices: indices,
    );
  }

  /// Finds all occurrences of [rawQuery] inside [originalText] using normalized
  /// comparison and returns their exact [HighlightRange]s in [originalText].
  static List<HighlightRange> findHighlightRanges(
    String originalText,
    String rawQuery,
  ) {
    if (originalText.isEmpty || rawQuery.trim().isEmpty) return const [];

    final normalizedQuery = normalize(rawQuery);
    if (normalizedQuery.isEmpty) return const [];

    final queryTokens = normalizedQuery
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (queryTokens.isEmpty) return const [];

    final mapping = normalizeWithMapping(originalText);
    final normText = mapping.normalizedText;
    if (normText.isEmpty) return const [];

    final targets = <String>[
      if (queryTokens.length > 1) queryTokens.join(' '),
      ...queryTokens,
    ];

    final rawRanges = <HighlightRange>[];

    for (final token in targets) {
      int searchFrom = 0;
      while (searchFrom < normText.length) {
        final foundIdx = normText.indexOf(token, searchFrom);
        if (foundIdx == -1) break;

        final endNormIdx = (foundIdx + token.length - 1)
            .clamp(0, mapping.originalIndices.length - 1);
        final origStart = mapping.originalIndices[foundIdx];
        int origEnd = mapping.originalIndices[endNormIdx] + 1;

        while (origEnd < originalText.length &&
            _isDiacriticOrTatweel(originalText.codeUnitAt(origEnd))) {
          origEnd++;
        }

        rawRanges.add(HighlightRange(start: origStart, end: origEnd));
        searchFrom = foundIdx + token.length;
      }
    }

    return _mergeOverlappingRanges(rawRanges);
  }

  /// Extracts a contextual snippet around the first match of [rawQuery] inside [content],
  /// along with highlight ranges relative to the snippet string.
  static SnippetExtractionResult extractSnippetWithHighlights(
    String content,
    String rawQuery, {
    int snippetRadius = 90,
  }) {
    if (content.trim().isEmpty) {
      return const SnippetExtractionResult(snippet: '', highlights: []);
    }

    final allMatches = findHighlightRanges(content, rawQuery);
    if (allMatches.isEmpty) {
      final cleanPreview = content
          .substring(0, content.length.clamp(0, snippetRadius * 2))
          .replaceAll('\n', ' ')
          .replaceAll('\r', ' ')
          .trim();
      return SnippetExtractionResult(snippet: cleanPreview, highlights: const []);
    }

    final firstMatch = allMatches.first;
    int snippetStart = (firstMatch.start - snippetRadius).clamp(0, content.length);
    int snippetEnd = (firstMatch.end + snippetRadius).clamp(0, content.length);

    if (snippetStart > 0) {
      final prevSpace = content.lastIndexOf(' ', snippetStart);
      if (prevSpace != -1 && (snippetStart - prevSpace) <= 20) {
        snippetStart = prevSpace + 1;
      }
    }

    if (snippetEnd < content.length) {
      final nextSpace = content.indexOf(' ', snippetEnd);
      if (nextSpace != -1 && (nextSpace - snippetEnd) <= 20) {
        snippetEnd = nextSpace;
      }
    }

    final prefix = snippetStart > 0 ? '… ' : '';
    final suffix = snippetEnd < content.length ? ' …' : '';

    final rawSlice = content
        .substring(snippetStart, snippetEnd)
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');

    final snippetText = '$prefix$rawSlice$suffix';
    final snippetHighlights = findHighlightRanges(snippetText, rawQuery);

    return SnippetExtractionResult(
      snippet: snippetText,
      highlights: snippetHighlights,
    );
  }

  static int _normalizeChar(int codeUnit) {
    if (_isDiacriticOrTatweel(codeUnit)) return 0;

    switch (codeUnit) {
      // Alef variants (آ, أ, إ, ٱ, ٲ, ٳ, ٵ) -> ا (0x0627)
      case 0x0622:
      case 0x0623:
      case 0x0625:
      case 0x0671:
      case 0x0672:
      case 0x0673:
      case 0x0675:
        return 0x0627;

      // Ta Marbuta (ة) -> Ha (ه 0x0647)
      case 0x0629:
        return 0x0647;

      // Alef Maqsura (ى), Farsi Yeh (ی), Yeh with Hamza (ئ) -> Yeh (ي 0x064A)
      case 0x0649:
      case 0x06CC:
      case 0x0626:
        return 0x064A;

      // Waw with Hamza (ؤ) -> Waw (و 0x0648)
      case 0x0624:
        return 0x0648;

      // Farsi Keheh (ک) -> Kaf (ك 0x0643)
      case 0x06A9:
        return 0x0643;

      // Newlines / tabs -> Space
      case 0x000A:
      case 0x000D:
      case 0x0009:
        return 0x0020;

      default:
        // Lowercase ASCII A-Z
        if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
          return codeUnit + 32;
        }
        return codeUnit;
    }
  }

  static bool _isDiacriticOrTatweel(int codeUnit) {
    return codeUnit == 0x0640 || // Tatweel (ـ)
        (codeUnit >= 0x064B && codeUnit <= 0x065F) || // Tashkeel / Harakat
        codeUnit == 0x0670 || // Superscript Alef
        (codeUnit >= 0x06D6 && codeUnit <= 0x06ED); // Quranic marks
  }

  static List<HighlightRange> _mergeOverlappingRanges(
    List<HighlightRange> ranges,
  ) {
    if (ranges.length <= 1) return ranges;
    final sorted = List<HighlightRange>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <HighlightRange>[];
    HighlightRange current = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (next.start <= current.end) {
        current = HighlightRange(
          start: current.start,
          end: next.end > current.end ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }
}
