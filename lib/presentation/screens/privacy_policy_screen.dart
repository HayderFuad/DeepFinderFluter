import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Built-in Privacy Policy Screen required for Google Play Store & Apple App Store compliance.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سياسة الخصوصية وأمن البيانات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.appNameAr} (${AppConstants.appNameEn}) — ${AppConstants.appVersionDisplay}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صُمم هذا التطبيق وفق مبدأ «الخصوصية أولاً (Privacy by Design)»، حيث يعمل كمحرك بحث محلي مستقل على جهازك 100%.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildPolicySection(
            context,
            icon: Icons.folder_open_outlined,
            title: '1. سبب طلب صلاحية الوصول للملفات',
            body:
                'يطلب التطبيق إذن قراءة المجلدات والملفات التي يحددها المستخدم (أو الوصول لتخزين الجهاز عند رغبة المستخدم) لغرض وحيد وحصري هو بناء فهرس بحث نصي محلي (SQLite FTS5) يمكّنك من العثور على ملفاتك والبحث داخل محتوى مستندات PDF و Word و Excel والملفات النصية بسرعة فائقة.',
          ),
          _buildPolicySection(
            context,
            icon: Icons.cloud_off_outlined,
            title: '2. عدم جمع أو مشاركة أي بيانات خارجياً (Zero Data Collection)',
            body:
                '• لا يمتلك التطبيق أي خوادم سحابية ولا يرسل أي ملفات أو نصوص أو أسماء مجلدات إلى الإنترنت.\n'
                '• لا يتضمن التطبيق أي حزم إعلانية أو أدوات تتبع سلوكي (Zero Tracking).\n'
                '• تُحفظ قاعدة بيانات الفهرس محلياً داخل المساحة الخاصة بالتطبيق على هاتفك فقط، وتُحذف تلقائياً بمجرد إلغاء تثبيت التطبيق.',
          ),
          _buildPolicySection(
            context,
            icon: Icons.security_outlined,
            title: '3. التزامنا بسياسات Google Play و Apple App Store',
            body:
                '• على نظام Android: نوفر نافذة إفصاح بارزة قبل طلب أي صلاحية، كما ندعم اختيار مجلدات محددة عبر إطار الوصول الآمن للملفات (SAF) دون إلزام المستخدم بصلاحية الوصول الكامل.\n'
                '• على نظام iOS: نلتزم كلياً بنظام (iOS App Sandbox) وملف الخصوصية الرسمي (PrivacyInfo.xcprivacy)، حيث يختار المستخدم المجلدات أو المستندات بنفسه عبر نافذة ملفات آبل الرسمية (UIDocumentPicker).',
          ),
          _buildPolicySection(
            context,
            icon: Icons.support_agent_outlined,
            title: '4. التواصل مع فريق التطوير',
            body:
                'لأي استفسارات تتعلق بالخصوصية أو الأمان، يمكنكم التواصل مباشرة مع مهندسي التطبيق:\n'
                '${AppConstants.developersNames}\n'
                'البريد الإلكتروني: ${AppConstants.emailDisplay}\n'
                'الهاتف: ${AppConstants.phone1Display} / ${AppConstants.phone2Display}',
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                height: 1.55,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
