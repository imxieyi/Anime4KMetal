#!/bin/bash
set -e

xcodebuild clean build -scheme 'Anime4KMetal (iOS)' -configuration Release \
    -destination generic/platform=macOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    CONFIGURATION_BUILD_DIR=$(pwd)/build-macos

cd build-macos
rm ../Anime4KMetal-macOS.zip || true
zip -r ../Anime4KMetal-macOS.zip Anime4KMetal.app
cd ..

xcodebuild clean build -scheme 'Anime4KMetal (iOS)' -configuration Release \
    -destination generic/platform=iOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    CONFIGURATION_BUILD_DIR=$(pwd)/build-ios

cd build-ios
mkdir Payload
mv Anime4KMetal.app Payload
rm ../Anime4KMetal-iOS.ipa || true
zip -r ../Anime4KMetal-iOS.ipa Payload
cd ..

xcodebuild clean build -scheme 'Anime4KMetal (tvOS)' -configuration Release \
    -destination generic/platform=tvOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    CONFIGURATION_BUILD_DIR=$(pwd)/build-tvos

cd build-tvos
mkdir Payload
mv Anime4KMetal.app Payload
rm ../Anime4KMetal-tvOS.ipa || true
zip -r ../Anime4KMetal-tvOS.ipa Payload
cd ..