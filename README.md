# LinkVault — iPhone + Web App + Supabase + Railway

هذه النسخة مبنية على مشروعك الحالي، وتم توسيعها حتى تكون أقرب لمنتج كامل بدل نسخة محلية فقط.

## المضاف في هذه النسخة

- تطبيق Web/PWA كامل داخل `www/`.
- مزامنة اختيارية عبر Supabase Auth + Database.
- حفظ محلي أولاً إذا لم تكن المزامنة مفعّلة.
- إعدادات داخل التطبيق لإضافة:
  - Supabase URL
  - Supabase anon public key
  - Railway Backend URL
- تسجيل دخول / إنشاء حساب من داخل التطبيق.
- رفع الروابط المحلية إلى Supabase.
- إضافة / تعديل / حذف الروابط.
- إضافة / حذف التصنيفات.
- لوقو المنصة حسب الرابط.
- ملاحظات لكل رابط.
- صورة مصغرة لكل رابط.
- جلب عنوان وصورة الرابط عبر Backend، مع دعم YouTube oEmbed بدون مفتاح.
- جلب تريلر الفيلم/المسلسل عبر Backend إذا تم وضع TMDB API key أو YouTube API key.
- fallback يفتح بحث YouTube جاهز إذا لم يوجد API key للتريلر.
- PWA Web Share Target للويب.
- iOS deep link: `linkvault://share`.
- ملفات iOS Share Extension يتم إضافتها تلقائيًا أثناء بناء Codemagic.
- `codemagic.yaml` محدث لبناء iOS ورفعه إلى TestFlight بدون ماك.

---

## 1) Supabase

### الخطوات
1. افتح Supabase.
2. افتح مشروعك.
3. روح إلى SQL Editor.
4. شغّل الملف:
   `supabase/schema.sql`
5. من Project Settings → API انسخ:
   - Project URL
   - anon public key
6. افتح LinkVault → الإعدادات → ضع القيم.
7. أنشئ حساب أو سجل دخول من داخل التطبيق.
8. اضغط "مزامنة الآن".

مهم: لا تضع Service Role Key داخل التطبيق.

---

## 2) Railway Backend

الـ Backend موجود داخل مجلد `backend/`.

### فائدته
- جلب عنوان وصورة الرابط من صفحات الويب العامة.
- تجاوز مشكلة CORS لأن الجلب يصير من السيرفر.
- البحث عن تريلر تلقائيًا عند توفر TMDB API Key أو YouTube API Key.

### النشر على Railway
1. ارفع المشروع إلى GitHub.
2. من Railway أنشئ مشروع جديد من GitHub.
3. اختر Root Directory: `backend`.
4. أضف Environment Variables:
   - `ALLOWED_ORIGINS=*` كبداية.
   - `TMDB_API_KEY` اختياري.
   - `YOUTUBE_API_KEY` اختياري.
5. بعد النشر انسخ رابط Railway وضعه في إعدادات LinkVault.

---

## 3) Web App / PWA

ملفات الويب داخل `www/`.

يمكن رفعها إلى:
- GitHub Pages
- Netlify
- Vercel
- أي استضافة static

بعد فتح الرابط من الجوال، ثبّت التطبيق على الشاشة الرئيسية.

ملاحظة مهمة: Web Share Target يعمل بشكل أفضل على Android وبعض المتصفحات. على iPhone الاعتماد الأفضل هو iOS Share Extension داخل التطبيق الأصلي.

---

## 4) iPhone بدون Mac عبر Codemagic

### المطلوب في Apple Developer / App Store Connect
- App ID للتطبيق:
  `com.linkvaultq8.app`
- App ID للـ Share Extension:
  `com.linkvaultq8.app.ShareExtension`
- App Group:
  `group.com.linkvaultq8.shared`
- تطبيق جديد في App Store Connect مربوط بـ Bundle ID الأساسي.

### المطلوب في Codemagic
1. اربط GitHub repo.
2. اربط App Store Connect integration باسم `codemagic`.
3. تأكد من وجود group باسم `code_signing` حسب إعداداتك السابقة.
4. شغّل workflow:
   `LinkVault iOS + Share Extension`

الـ workflow سيقوم بـ:
- تثبيت npm dependencies.
- إنشاء iOS project إذا غير موجود.
- مزامنة Capacitor.
- إضافة Share Extension تلقائيًا.
- جلب signing files للتطبيق والـ extension.
- بناء IPA.
- رفع النسخة إلى TestFlight.

---

## 5) ملفات مهمة

```
.
├── www/                         تطبيق الويب/PWA
│   ├── index.html
│   ├── app-config.js             إعدادات عامة اختيارية
│   ├── manifest.json
│   └── sw.js
├── backend/                      Railway Backend
│   ├── server.js
│   ├── package.json
│   └── .env.example
├── supabase/
│   └── schema.sql                جداول Supabase وسياسات RLS
├── ios-share-extension/          ملفات Share Extension الأصلية
│   ├── Info.plist
│   └── ShareViewController.swift
├── scripts/
│   └── add-ios-share-extension.rb
├── capacitor.config.json
├── package.json
└── codemagic.yaml
```

---

## 6) ملاحظات مهمة

- لا توجد مفاتيح سرية داخل الملفات.
- Supabase anon key مسموح يكون داخل التطبيق، لكن Service Role Key ممنوع.
- TMDB/Youtube keys تكون في Railway فقط.
- أول Build على Codemagic قد يحتاج تعديل بسيط حسب حالة Apple signing عندك. إذا فشل، افتح log وأرسل الخطأ فقط.

## Build fix note

This package enables App Group entitlements by default. The app and Share Extension must both use the exact same App Group ID: `group.com.linkvaultq8.shared`. Make sure this App Group is enabled in Apple Developer for both Bundle IDs before building for TestFlight/App Store.

## Share save reliability update

This package saves links from the iOS Share Extension into a persistent App Group queue without attempting to open the main app. Every new share is appended to the queue instead of replacing the previous link. When LinkVault is opened, the app imports all queued links in order and removes only the entries that were imported successfully.

The Share Extension also uses the LinkVault dark theme, keeps the save controls above the keyboard, and allows the form content to scroll while notes are being entered.
