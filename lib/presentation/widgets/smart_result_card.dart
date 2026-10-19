import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../data/models/indexed_file_model.dart';

/// Displays a single matched file or folder with:
/// - Color-coded category icon
/// - Highlighted filename (`RichText` / `TextSpan`)
/// - Readable file path, formatted size, and modification date
/// - Deep Content **Snippet Box** with highlighted query words when matched inside the file
/// - Quick actions: Open (`open_filex`), Share (`share_plus`), and Copy path/snippet
class SmartResultCard extends StatelessWidget {
  final SearchResultItem item;

  const SmartResultCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightBg =
        isDark ? AppTheme.highlightBgDark : AppTheme.highlightBgLight;
    final highlightFg =
        isDark ? AppTheme.highlightFgDark : AppTheme.highlightFgLight;

    final (iconData, iconColor) = _resolveCategoryVisuals(item.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openFile(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: File Icon + Name + Match Scope Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(iconData, color: iconColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: _buildHighlightedSpan(
                                  text: item.fileName,
                                  ranges: item.nameHighlights,
                                  baseStyle: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                  highlightBg: highlightBg,
                                  highlightFg: highlightFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildMatchBadge(context, item.matchScope),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            item.displayPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildMetaText(),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Deep Content Snippet Box
              if (item.snippetText != null &&
                  item.snippetText!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'مقتطف من داخل المحتوى:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        text: _buildHighlightedSpan(
                          text: item.snippetText!,
                          ranges: item.snippetHighlights,
                          baseStyle: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: colorScheme.onSurface,
                          ),
                          highlightBg: highlightBg,
                          highlightFg: highlightFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Quick Action Buttons (Open, Share, Copy)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openFile(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('فتح', style: TextStyle(fontSize: 12.5)),
                  ),
                  if (!item.isDirectory)
                    TextButton.icon(
                      onPressed: () => _shareFile(context),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label:
                          const Text('مشاركة', style: TextStyle(fontSize: 12.5)),
                    ),
                  TextButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      (item.snippetText != null && item.snippetText!.isNotEmpty)
                          ? 'نسخ النص'
                          : 'نسخ المسار',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedSpan({
    required String text,
    required List<HighlightRange> ranges,
    required TextStyle baseStyle,
    required Color highlightBg,
    required Color highlightFg,
  }) {
    if (ranges.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int currentIdx = 0;

    for (final range in ranges) {
      final start = range.start.clamp(0, text.length);
      final end = range.end.clamp(start, text.length);

      if (start > currentIdx) {
        spans.add(
          TextSpan(
            text: text.substring(currentIdx, start),
            style: baseStyle,
          ),
        );
      }

      if (end > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(
              backgroundColor: highlightBg,
              color: highlightFg,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      currentIdx = end;
    }

    if (currentIdx < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIdx),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildMatchBadge(BuildContext context, MatchScope scope) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (scope) {
      MatchScope.nameAndContent => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer
        ),
      MatchScope.contentOnly => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer
        ),
      MatchScope.nameOnly => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        scope.badgeAr,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  (IconData, Color) _resolveCategoryVisuals(FileCategory category) {
    switch (category) {
      case FileCategory.pdf:
        return (Icons.picture_as_pdf_rounded, AppTheme.pdfColor);
      case FileCategory.word:
        return (Icons.description_rounded, AppTheme.wordColor);
      case FileCategory.excel:
        return (Icons.table_chart_rounded, AppTheme.excelColor);
      case FileCategory.folder:
        return (Icons.folder_rounded, AppTheme.folderColor);
      case FileCategory.text:
        return (Icons.article_rounded, AppTheme.textColor);
      case FileCategory.other:
        return (Icons.insert_drive_file_rounded, AppTheme.otherFileColor);
    }
  }

  String _buildMetaText() {
    final dateStr = item.lastModifiedMs > 0
        ? DateFormat('yyyy/MM/dd').format(
            DateTime.fromMillisecondsSinceEpoch(item.lastModifiedMs),
          )
        : '';
    if (item.isDirectory) {
      return 'مجلد • $dateStr';
    }
    return '${_formatBytes(item.sizeBytes)} • ${item.category.labelAr} • $dateStr';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<void> _openFile(BuildContext context) async {
    final result = await OpenFilex.open(item.filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الملف: ${result.message}')),
      );
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      await Share.shareXFiles([XFile(item.filePath)], text: item.fileName);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذرت مشاركة الملف')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final textToCopy =
        (item.snippetText != null && item.snippetText!.trim().isNotEmpty)
            ? item.snippetText!
            : item.filePath;
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم النسخ إلى الحافظة بنجاح')),
      );
    }
  }
}
