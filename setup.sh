#!/usr/bin/env bash
# Gera a pasta android/, ícones e splash. Rode uma vez após baixar o projeto.
set -e
flutter create --org com.hospitalempire --project-name hospital_empire --platforms android .
rm -f test/widget_test.dart
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="Hospital Empire"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
echo "✅ Projeto pronto. Teste com: flutter run   |   APK: flutter build apk --release   |   AAB: flutter build appbundle --release"
