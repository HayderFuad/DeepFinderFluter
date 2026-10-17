import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

/// Professional "Contact Us & Developer Credits" Modal BottomSheet for DeepFinder v1.
///
/// Displays:
/// - Version badge: `Version: v1 (1.0.0)`
/// - Developers: `Eng. Hayder Fuad & Eng. Ebraheem Ahmed`
/// - Interactive buttons via `url_launcher` for Phone 1, Phone 2, WhatsApp,
///   Email, Instagram, Telegram, Facebook, and GitHub.
class ContactUsSheet extends StatelessWidget {
  const ContactUsSheet({super.key});

  Future<void> _launchExternalUri(BuildContext context, String uriString) async {
    final uri = Uri.parse(uriString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح الرابط: $uriString')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد تطبيق متاح لفتح: $uriString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // App Header & Version v1 Badge
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.manage_search_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الباحث العميق — DeepFinder',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Version: ${AppConstants.appVersionDisplay}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Developers Credits Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.engineering_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'تطوير وهندسة البرمجيات (Developers):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        AppConstants.developersNames,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'قنوات التواصل المباشر:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),

              // Phone 1 (Direct Call + WhatsApp)
              _ContactTile(
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFF1E88E5),
                title: 'هاتف رقم 1 (اتصال مباشر / واتساب)',
                subtitle: AppConstants.phone1Display,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.phone1TelUri),
                trailingAction: IconButton.filledTonal(
                  tooltip: 'مراسلة عبر واتساب',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  onPressed: () => _launchExternalUri(
                    context,
                    AppConstants.phone1WhatsAppUri,
                  ),
                ),
              ),

              // Phone 2 (Direct Call + WhatsApp)
              _ContactTile(
                icon: Icons.phone_android_rounded,
                iconColor: const Color(0xFF00897B),
                title: 'هاتف رقم 2 (اتصال مباشر / واتساب)',
                subtitle: AppConstants.phone2Display,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.phone2TelUri),
                trailingAction: IconButton.filledTonal(
                  tooltip: 'مراسلة عبر واتساب',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  onPressed: () => _launchExternalUri(
                    context,
                    AppConstants.phone2WhatsAppUri,
                  ),
                ),
              ),

              // Email
              _ContactTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFFE53935),
                title: 'البريد الإلكتروني الرسمي (Email)',
                subtitle: AppConstants.emailDisplay,
                onTap: () => _launchExternalUri(context, AppConstants.emailUri),
              ),

              // Instagram
              _ContactTile(
                icon: Icons.camera_alt_outlined,
                iconColor: const Color(0xFFD81B60),
                title: 'إنستغرام (Instagram)',
                subtitle: AppConstants.instagramHandle,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.instagramUri),
              ),

              // Telegram
              _ContactTile(
                icon: Icons.send_rounded,
                iconColor: const Color(0xFF039BE5),
                title: 'تيليجرام (Telegram)',
                subtitle: AppConstants.telegramHandle,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.telegramUri),
              ),

              // Facebook
              _ContactTile(
                icon: Icons.public_rounded,
                iconColor: const Color(0xFF1565C0),
                title: 'فيسبوك (Facebook)',
                subtitle: AppConstants.facebookHandle,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.facebookUri),
              ),

              // LinkedIn
              _ContactTile(
                icon: Icons.work_outline_rounded,
                iconColor: const Color(0xFF0A66C2),
                title: 'لينكدإن (LinkedIn)',
                subtitle: AppConstants.linkedinDisplay,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.linkedinUri),
              ),

              // GitHub
              _ContactTile(
                icon: Icons.code_rounded,
                iconColor: const Color(0xFF37474F),
                title: 'حساب المطور على GitHub',
                subtitle: AppConstants.githubHandle,
                onTap: () =>
                    _launchExternalUri(context, AppConstants.githubUri),
              ),

              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('إغلاق النافذة'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailingAction;

  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              subtitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
        trailing: trailingAction ??
            const Icon(Icons.open_in_new_rounded, size: 18),
      ),
    );
  }
}
