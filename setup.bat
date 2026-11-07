@echo off
REM Gera a pasta android/, icones e splash (Windows).
call flutter create --org com.hospitalempire --project-name hospital_empire --platforms android .
if exist test\widget_test.dart del test\widget_test.dart
call flutter pub get
call dart run flutter_launcher_icons
call dart run flutter_native_splash:create
powershell -Command "(Get-Content android\app\src\main\AndroidManifest.xml) -replace 'android:label=\"[^\"]*\"', 'android:label=\"Hospital Empire\"' | Set-Content android\app\src\main\AndroidManifest.xml"
echo Projeto pronto! Rode: flutter run
