import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/indexed_file_model.dart';
import '../providers/search_index_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/contact_us_sheet.dart';
import '../widgets/prominent_disclosure_dialog.dart';
import '../widgets/smart_result_card.dart';
import 'privacy_policy_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openContactUsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactUsSheet(),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _handleFullDeviceScanRequest() {
    final state = ref.read(searchIndexProvider);
    final notifier = ref.read(searchIndexProvider.notifier);

    if (Platform.isIOS) {
      notifier.pickDirectoryAndIndex();
      return;
    }

    // Show Mandatory Google Play Prominent Disclosure Dialog before permission prompt
    if (!state.hasShownDisclosure) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProminentDisclosureDialog(
          onAcceptFullScan: () async {
            await notifier.markDisclosureAccepted();
            await notifier.requestFullStorageAndIndex();
          },
          onChooseSafeFolderInstead: () async {
            await notifier.markDisclosureAccepted();
            await notifier.pickDirectoryAndIndex();
          },
          onOpenPrivacyPolicy: _openPrivacyPolicy,
        ),
      );
    } else {
      notifier.requestFullStorageAndIndex();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchIndexProvider);
    final notifier = ref.read(searchIndexProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Display non-intrusive status message snackbar when needed
    ref.listen<SearchIndexState>(searchIndexProvider, (prev, next) {
      if (next.statusMessage != null &&
          next.statusMessage != prev?.statusMessage &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.statusMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              AppConstants.appNameAr,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'v1',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Quick Light / Dark Mode Toggle Button in AppBar
          IconButton(
            tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الغامق',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          // Contact Us & Developer Credits Icon in AppBar
          IconButton(
            tooltip: 'تواصل معنا / حول التطبيق',
            icon: const Icon(Icons.contact_support_outlined),
            onPressed: _openContactUsSheet,
          ),
          // Privacy Policy Icon
          IconButton(
            tooltip: 'سياسة الخصوصية',
            icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: _openPrivacyPolicy,
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(context, isDark),
      body: Column(
        children: [
          // Search Bar + Filter Chips + Indexing Banner Container
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                // Instant Search Input Field
                TextField(
                  controller: _searchController,
                  onChanged: notifier.onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText:
                        'ابحث عن اسم ملف أو نص بداخل PDF, Word, Excel…',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: colorScheme.primary),
                    suffixIcon: state.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              notifier.clearQuery();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.65),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Horizontal Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: SearchFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = SearchFilter.values[index];
                      final selected = state.selectedFilter == filter;
                      return FilterChip(
                        selected: selected,
                        label: Text(
                          filter.labelAr,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onSelected: (_) => notifier.selectFilter(filter),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Indexing Status & Action Bar
                _buildIndexingStatusCard(context, state, notifier),
              ],
            ),
          ),

          const Divider(height: 1),

          // Search Results List or Empty State
          Expanded(
            child: state.results.isEmpty
                ? _buildEmptyState(context, state)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: state.results.length,
                    itemBuilder: (context, index) {
                      return SmartResultCard(item: state.results[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexingStatusCard(
    BuildContext context,
    SearchIndexState state,
    SearchIndexNotifier notifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (state.progressFraction * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.isIndexing
                    ? Icons.sync_rounded
                    : Icons.storage_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.isIndexing
                      ? 'جاري الفهرسة في الخلفية ($percent%) — ${state.indexedCount} / ${state.totalEstimatedCount}'
                      : 'المفهرس: ${state.totalFilesInDb} ملف ومجلد (${state.deepFilesInDb} مستند عميق)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (state.query.isNotEmpty)
                Text(
                  '${state.searchLatencyMs.toStringAsFixed(1)} ms',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (state.isIndexing) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.totalEstimatedCount > 0
                    ? state.progressFraction
                    : null,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.currentIndexingFile,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: notifier.cancelIndexing,
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text('إيقاف مكتفٍ بما فُهرس', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.tonalIcon(
                  onPressed: notifier.pickDirectoryAndIndex,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                  label: const Text(
                    'إضافة مجلد للفهرسة',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (Platform.isAndroid)
                  OutlinedButton.icon(
                    onPressed: _handleFullDeviceScanRequest,
                    icon: const Icon(Icons.phone_android_rounded, size: 17),
                    label: const Text(
                      'فحص شامل للهاتف',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                IconButton.filledTonal(
                  tooltip: 'تحديث الفهرس الحالي',
                  onPressed: () => notifier.refreshIndex(forceRebuild: false),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SearchIndexState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.manage_search_rounded,
                size: 54,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.query.isEmpty
                  ? 'مرحباً بك في الباحث العميق DeepFinder v1'
                  : 'لا توجد نتائج مطابقة لـ «${state.query}»',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.query.isEmpty
                  ? 'اضغط على «إضافة مجلد للفهرسة» أو «فحص شامل للهاتف» للبدء بالبحث الفوري في أسماء الملفات وبداخل محتوى PDF و Word و Excel والملفات النصية.'
                  : 'جرّب البحث بكلمات أخرى أو تغيير فلتر التصنيف أعلاه.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, bool isDark) {
    final notifier = ref.read(searchIndexProvider.notifier);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.manage_search_rounded),
              ),
              title: const Text(
                AppConstants.appNameAr,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Version: ${AppConstants.appVersionDisplay}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('إضافة مجلد للفهرسة (آمن)'),
              onTap: () {
                Navigator.pop(context);
                notifier.pickDirectoryAndIndex();
              },
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.phone_android_rounded),
                title: const Text('الفحص الشامل للهاتف'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFullDeviceScanRequest();
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('إعادة بناء الفهرس بالكامل'),
              onTap: () {
                Navigator.pop(context);
                notifier.refreshIndex(forceRebuild: true);
              },
            ),
            ListTile(
              leading: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              title: Text(
                isDark ? 'التبديل إلى الوضع الفاتح' : 'التبديل إلى الوضع الغامق',
              ),
              onTap: () {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('سياسة الخصوصية وأمن البيانات'),
              onTap: () {
                Navigator.pop(context);
                _openPrivacyPolicy();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_support_outlined),
              title: const Text('تواصل معنا / فريق التطوير'),
              onTap: () {
                Navigator.pop(context);
                _openContactUsSheet();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppConstants.developersNames,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
