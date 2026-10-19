import 'package:flutter/material.dart';

/// Google Play Store Mandatory Prominent Disclosure Dialog.
///
/// Must be displayed BEFORE triggering any system runtime permission prompt
/// (`MANAGE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE`) so the user clearly
/// understands why file access is requested and that all processing is 100% local.
class ProminentDisclosureDialog extends StatelessWidget {
  final VoidCallback onAcceptFullScan;
  final VoidCallback onChooseSafeFolderInstead;
  final VoidCallback onOpenPrivacyPolicy;

  const ProminentDisclosureDialog({
    super.key,
    required this.onAcceptFullScan,
    required this.onChooseSafeFolderInstead,
    required this.onOpenPrivacyPolicy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.privacy_tip_outlined,
          size: 34,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: const Text(
        'إفصاح هام حول صلاحية الوصول للملفات',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لكي يتمكن تطبيق «الباحث العميق DeepFinder v1» من البحث الفوري في أسماء الملفات وبداخل محتوى مستنداتك (PDF, Word, Excel, النصوص)، يحتاج التطبيق إلى صلاحية قراءة الملفات في جهازك.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ضمان الخصوصية والأمان (100% Offline):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• تتم فهرسة الملفات واستخراج النصوص محلياً بالكامل داخل جهازك فقط.\n'
                    '• لا يجمع التطبيق أو يرفع أو يشارك أي ملفات أو نصوص مع أي خادم خارجي نهائياً.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenPrivacyPolicy,
                icon: const Icon(Icons.policy_outlined, size: 18),
                label: const Text('قراءة سياسة الخصوصية الكاملة'),
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onAcceptFullScan();
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('موافق — منح صلاحية البحث الشامل'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onChooseSafeFolderInstead();
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('اختيار مجلد محدد فقط (بدون صلاحية شاملة)'),
            ),
          ],
        ),
      ],
    );
  }
}
