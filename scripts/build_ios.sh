#!/usr/bin/env bash
set -e

flutter clean
flutter pub get
cd ios
pod repo update
pod install
cd ..
flutter build ios --release
