@echo off
echo ===================================================
echo Reparación de Estadísticas para BiLink
echo ===================================================

cd /d %~dp0

echo Ejecutando script de reparación de estadísticas...
flutter run -d windows repair_statistics.dart

echo.
echo Reparación completada.
echo.
echo Ahora las estadísticas deberían calcularse correctamente.
echo Reinicie la aplicación y vaya a la página de estadísticas para verificar.
echo.
pause
