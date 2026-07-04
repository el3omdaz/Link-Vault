# LinkVault Backend — Railway

هذا backend اختياري لكنه مهم لجلب بيانات الروابط العامة والتريلرات بدون مشاكل CORS.

## التشغيل على Railway
1. افتح Railway وأنشئ مشروع جديد من GitHub.
2. اجعل Root Directory هو `backend`.
3. أضف Environment Variables:
   - `ALLOWED_ORIGINS=*` كبداية، وبعدها غيّرها إلى رابط موقعك.
   - `TMDB_API_KEY` اختياري لجلب التريلر تلقائيًا.
   - `YOUTUBE_API_KEY` اختياري كبديل لجلب أول نتيجة تريلر من يوتيوب.
4. بعد النشر انسخ رابط Railway وضعه في إعدادات LinkVault في خانة Backend URL.

## endpoints
- `GET /api/health`
- `GET /api/metadata?url=https://...`
- `GET /api/trailer?title=Movie%20Name`
