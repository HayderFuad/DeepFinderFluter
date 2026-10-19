/// Application metadata, developer credits, and store compliance constants
/// for DeepFinder v1 (1.0.0+1).
class AppConstants {
  AppConstants._();

  static const String appNameAr = 'الباحث العميق';
  static const String appNameEn = 'DeepFinder';
  static const String appVersionDisplay = 'v1 (1.0.0)';
  static const String appBuildNumber = '1.0.0+1';

  // Developers & Credits
  static const String developersNames = 'Eng. Hayder Fuad & Eng. Ebraheem Ahmed';
  static const String developer1Name = 'Eng. Hayder Fuad';
  static const String developer2Name = 'Eng. Ebraheem Ahmed';

  // Official Contact Links
  static const String phone1Display = '+967776797221';
  static const String phone1TelUri = 'tel:+967776797221';
  static const String phone1WhatsAppUri = 'https://wa.me/967776797221';

  static const String phone2Display = '+967734414267';
  static const String phone2TelUri = 'tel:+967734414267';
  static const String phone2WhatsAppUri = 'https://wa.me/967734414267';

  static const String emailDisplay = 'asydalwr@gmail.com';
  static const String emailUri = 'mailto:asydalwr@gmail.com?subject=DeepFinder%20v1%20Feedback';

  static const String instagramHandle = '@riv.m4';
  static const String instagramUri = 'https://instagram.com/riv.m4';

  static const String telegramHandle = '@riv_m4';
  static const String telegramUri = 'https://t.me/riv_m4';

  static const String facebookHandle = '@riv.m4';
  static const String facebookUri = 'https://facebook.com/riv.m4';

  static const String linkedinDisplay = 'www.linkedin.com/in/hayderf';
  static const String linkedinUri = 'https://www.linkedin.com/in/hayderf';

  static const String githubHandle = '@HayderFuad';
  static const String githubUri = 'https://github.com/HayderFuad';

  // Supported Extensions for Deep Content Extraction
  static const Set<String> supportedDeepExtensions = {
    'txt',
    'md',
    'json',
    'csv',
    'xml',
    'log',
    'pdf',
    'docx',
    'xlsx',
  };

  // Default Excluded System/Cache/Media Folders for Fast & Safe Full Scan
  static const List<String> defaultExcludedFolders = [
    '.thumbnails',
    'Android/data',
    'Android/obb',
    'Android/media',
    'DCIM/.thumbnails',
    'DCIM/Camera',
    'Pictures/.thumbnails',
    'Movies',
    'Music',
    'Ringtones',
    'Alarms',
    'Notifications',
    'WhatsApp Voice Notes',
    'WhatsApp Video',
    'WhatsApp Images',
    'WhatsApp Animated Gifs',
    'WhatsApp Stickers',
    'Telegram Video',
    'Telegram Audio',
    'Telegram Images',
    'node_modules',
    '.git',
    '.dart_tool',
    '.gradle',
    'build',
    '.cache',
    'cache',
  ];
}
