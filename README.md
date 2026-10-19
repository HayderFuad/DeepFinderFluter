# الباحث العميق — DeepFinder v1 (`1.0.0+1`)
محرك البحث الذكي الشامل في أسماء الملفات ومحتواها العميق (**Flutter & Dart 3 — Android & iOS**).
-----


---

## 🌟 نظرة عامة (Overview)
**DeepFinder** هو تطبيق أندرويد محلي فائق السرعة والأمان، يتيح البحث الفوري في الهاتف الذكي عن أي نص أو مستند من مستويين:
1. **تطابق الأسماء (Metadata):** أي ملف أو مجلد يحتوي اسمه على كلمة البحث.
2. **تطابق المحتوى العميق (Deep Content Match):** البحث داخل نصوص المستندات (`PDF, Word/DOCX, Excel/XLSX, TXT, MD, JSON, CSV, XML, LOG, Code`) وعرض مقتطف (Snippet) من الجملة مع تظليل الكلمات المطابقة.
3. **محرك تطبيع اللغة العربية (Arabic Normalizer):** توحيد الهمزات (أ، إ، آ -> ا)، التاء المربوطة (ة -> ه)، الألف المقصورة (ى -> ي)، وإزالة التشكيل (الحركات) والمد (Tatweel) لضمان العثور على الأسماء العربية بدقة 100%.
4. **أمان وخصوصية 100% (Zero-Internet):** التطبيق أوفلاين تماماً ولا يطلب إذن الإنترنت في المانيفست.
5. **قفل التطبيق بالبصمة (Biometric Lock):** حماية نتائج البحث الحساسة ببصمة الإصبع أو رمز قفل الشاشة.

---

- **الإصدار:** `v1 (1.0.0+1)`
- **المهندسون المطورون:** `Eng. Hayder Fuad & Eng. Ebraheem Ahmed`
- **قنوات التواصل الرسمية:**
  - هاتف 1 / واتساب: `+967776797221`
  - هاتف 2 / واتساب: `+967734414267`
  - البريد الإلكتروني: `asydalwr@gmail.com`
  - إنستغرام: `@riv.m4` (`https://instagram.com/riv.m4`)
  - تيليجرام: `@riv_m4` (`https://t.me/riv_m4`)
  - فيسبوك: `@riv.m4` (`https://facebook.com/riv.m4`)
  - لينكدإن (LinkedIn): `www.linkedin.com/in/hayderf` (`https://www.linkedin.com/in/hayderf`)
  - GitHub: `@HayderFuad` (`https://github.com/HayderFuad`)

## الأوامر السريعة للتشغيل والبناء
```bash
# 1. تحميل الحزم
flutter pub get

# 2. تشغيل التطبيق مباشرة
flutter run

# 3. بناء نسخة APK للتجربة المباشرة (Android)
flutter build apk --release

# 4. بناء حزمة Google Play Store الموقعة (.aab)
flutter build appbundle --release

# 5. بناء حزمة Apple App Store (.ipa) على macOS
flutter build ipa --release
```
