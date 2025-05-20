@echo off
REM Script para corregir estadísticas de proveedores
echo Iniciando corrección de estadísticas de proveedores...

cd /d %~dp0
flutter run -d windows fix_provider_statistics.dart

echo.
echo Corrección de estadísticas completada.
pause
