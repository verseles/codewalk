.PHONY: help deps gen icons icons-check analyze test coverage check android precommit clean

APK_DIR = build/app/outputs/flutter-apk
APK_PATH = $(APK_DIR)/codewalk.apk
ANALYZE_LOG = /tmp/flutter_analyze.log
TDL_CHANNEL = VerselesBot
TDL_TARGET = 6

help:
	@echo "CodeWalk Make Targets"
	@echo ""
	@echo "  make deps       Install dependencies"
	@echo "  make gen        Run build_runner"
	@echo "  make icons      Regenerate app icons (standard + adaptive)"
	@echo "  make icons-check Validate icon artifacts and dimensions"
	@echo "  make analyze    Run static analysis + issue budget gate"
	@echo "  make test       Run tests"
	@echo "  make coverage   Run tests with coverage + threshold gate"
	@echo "  make check      deps + gen + analyze + test"
	@echo "  make android    Build Android APK (arm64)"
	@echo "  make precommit  check + android"
	@echo "  make clean      Clean and restore dependencies"

deps:
	flutter pub get

gen:
	dart run build_runner build --delete-conflicting-outputs

icons:
	@if [ ! -f "assets/images/original.png" ]; then \
		echo "Missing source image: assets/images/original.png"; \
		exit 1; \
	fi
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make icons."; \
		exit 1; \
	fi
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 720x775\! -strip -define png:compression-level=9 assets/images/icon.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 256x256\! -strip -define png:compression-level=9 assets/images/logo.256.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 1024x1024\! -strip -define png:compression-level=9 assets/images/logo.1024.png
	magick assets/images/original.png -gravity center -crop 78%x78%+0+0 +repage -resize 1024x1024\! -strip -define png:compression-level=9 assets/images/adaptive_foreground.png
	mkdir -p linux/runner/resources
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 512x512\! -strip -define png:compression-level=9 linux/runner/resources/app_icon.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 1024x1024\! -define icon:auto-resize=256,128,64,48,32,24,16 windows/runner/resources/app_icon.ico
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 16x16\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 32x32\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 64x64\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 128x128\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 256x256\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 512x512\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 1024x1024\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
	dart run flutter_launcher_icons
	# Web maskable icons with safe zone: keep critical subject inside center area.
	magick -size 1024x1024 xc:'#7EAFC2' \( assets/images/original.png -gravity center -crop 90%x90%+0+0 +repage -resize 840x840\! \) -gravity center -composite -strip -define png:compression-level=9 web/icons/Icon-maskable-512.png
	magick web/icons/Icon-maskable-512.png -resize 192x192\! -strip -define png:compression-level=9 web/icons/Icon-maskable-192.png
	@echo "Icons regenerated for Android + Linux + Windows + macOS."

icons-check:
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make icons-check."; \
		exit 1; \
	fi
	@set -e; \
	for f in \
		assets/images/icon.png \
		assets/images/adaptive_foreground.png \
		linux/runner/resources/app_icon.png \
		windows/runner/resources/app_icon.ico \
		android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png \
		macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png \
		web/icons/Icon-maskable-192.png \
		web/icons/Icon-maskable-512.png; do \
		test -f "$$f" || { echo "Missing icon artifact: $$f"; exit 1; }; \
	done
	@test "$$(magick identify -format '%wx%h' assets/images/icon.png)" = "720x775" || (echo "Invalid assets/images/icon.png size"; exit 1)
	@test "$$(magick identify -format '%wx%h' assets/images/adaptive_foreground.png)" = "1024x1024" || (echo "Invalid assets/images/adaptive_foreground.png size"; exit 1)
	@test "$$(magick identify -format '%wx%h' linux/runner/resources/app_icon.png)" = "512x512" || (echo "Invalid linux app icon size"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png)" = "16x16" || (echo "Invalid macOS 16x16 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png)" = "32x32" || (echo "Invalid macOS 32x32 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png)" = "64x64" || (echo "Invalid macOS 64x64 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png)" = "128x128" || (echo "Invalid macOS 128x128 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png)" = "256x256" || (echo "Invalid macOS 256x256 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png)" = "512x512" || (echo "Invalid macOS 512x512 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png)" = "1024x1024" || (echo "Invalid macOS 1024x1024 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' web/icons/Icon-maskable-192.png)" = "192x192" || (echo "Invalid web maskable 192 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' web/icons/Icon-maskable-512.png)" = "512x512" || (echo "Invalid web maskable 512 icon"; exit 1)
	@grep -q 'android:inset="0%"' android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml || (echo "Adaptive icon inset is not 0%"; exit 1)
	@echo "Icon checks passed."

analyze:
	flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee $(ANALYZE_LOG)
	bash tool/ci/check_analyze_budget.sh $(ANALYZE_LOG) 186

test:
	flutter test

coverage:
	flutter test --coverage
	bash tool/ci/check_coverage.sh coverage/lcov.info 35

check: deps gen analyze test

android:
	flutter build apk --release --target-platform android-arm64
	@if [ -f "$(APK_DIR)/app-release.apk" ]; then \
		mv -f "$(APK_DIR)/app-release.apk" "$(APK_PATH)"; \
		echo "APK ready: $(APK_PATH)"; \
	else \
		echo "APK output not found at $(APK_DIR)/app-release.apk"; \
		exit 1; \
	fi
	@if command -v tdl >/dev/null 2>&1; then \
		echo "Uploading APK via tdl..."; \
		if tdl up -c "$(TDL_CHANNEL)" -t "$(TDL_TARGET)" --path="$(APK_PATH)"; then \
			echo "APK uploaded via tdl."; \
		else \
			echo "tdl upload failed."; \
			exit 1; \
		fi; \
	else \
		echo "tdl not found - upload skipped."; \
	fi

precommit: check icons-check android

clean:
	flutter clean
	flutter pub get
