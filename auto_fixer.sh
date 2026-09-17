#!/bin/bash

echo "🔄 بدء تشغيل سكريبت الإصلاح والرفع التلقائي..."

MAX_ATTEMPTS=5
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "----------------------------------------"
    echo "⚙️ المحاولة رقم $ATTEMPT من $MAX_ATTEMPTS..."

    # 1. فحص وتوليد ملفات Flutter إذا كانت مفقودة
    if [ ! -f "pubspec.yaml" ]; then
        echo "🛠️ إنشاء هيكل مشروع Flutter الأساسي..."
        cat << 'EOP' > pubspec.yaml
name: etactix_app
description: "eTactix Pro App"
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
EOP

        mkdir -p lib
        cat << 'EOM' > lib/main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('eTactix AI Engine Active')),
    ),
  ));
}
EOM
    fi

    # 2. إنشاء وتحديث سيرفر البناء GitHub Actions
    mkdir -p .github/workflows
    cat << 'EOW' > .github/workflows/build.yml
name: Build Flutter APK
on: [push, workflow_dispatch]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: etactix-pro-apk
          path: build/app/outputs/flutter-apk/app-release.apk
EOW

    # 3. تنظيف الملفات الحساسة والتسريبات المحظورة
    git rm -r --cached .config 2>/dev/null
    rm -rf .config
    echo ".config/" >> .gitignore
    echo ".env" >> .gitignore

    # 4. حفظ التغييرات ومحاولة الرفع
    git add .
    git commit -m "Auto-fix and re-trigger CI/CD (Attempt $ATTEMPT)" 2>/dev/null

    echo "🚀 محاولة الرفع إلى GitHub..."
    if git push -u origin main --force; then
        echo "========================================"
        echo "✅ تم الإصلاح والرفع بنجاح! السيرفر يبني الآن."
        echo "========================================"
        exit 0
    else
        echo "⚠️ فشلت محاولة الرفع. جاري التطبيق والإعادة..."
        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    fi
done

echo "❌ انتهت المحاولات التلقائية. يرجى التأكد من صلاحية Personal Access Token الخاصة بك."
