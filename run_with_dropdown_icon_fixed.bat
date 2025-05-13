@echo off
echo جاري تشغيل تطبيق BiLink مع إصلاح مشكلة أيقونة القائمة المنسدلة...
echo هذا الإصلاح يستبدل الرمز Icons.arrow_drop_down بالرمز Icons.expand_more لمنع توقف التطبيق

cd /d "%~dp0"
flutter run -d windows --no-sound-null-safety
