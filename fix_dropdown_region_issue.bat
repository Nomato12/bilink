@echo off
echo ====================================
echo تطبيق إصلاح مشكلة القائمة المنسدلة
echo ====================================
echo.
echo جارٍ تنظيف التطبيق...
flutter clean

echo.
echo جارٍ الحصول على التبعيات...
flutter pub get

echo.
echo جارٍ تشغيل التطبيق...
flutter run

echo.
echo تم تطبيق الإصلاح بنجاح!
