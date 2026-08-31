.PHONY: help deps gen theme-sync theme-sync-check icons icons-tray icons-app tray-prepare icons-check analyze test test-fast test-unit test-widget test-integration test-shard coverage smoke check check-fast web desktop android precommit clean release

APK_DIR = build/app/outputs/flutter-apk
APK_PATH = $(APK_DIR)/codewalk.apk
APK_METADATA_PATH = $(patsubst %/flutter-apk,%/apk/release,$(APK_DIR))/output-metadata.json
ANDROID_KEY_PROPERTIES = android/key.properties
ANALYZE_LOG = /tmp/flutter_analyze.log
TEST_JOBS ?= 12
FAST_EXCLUDE_TAGS ?= slow,integration
ANDROID_BUILD_CODE_OFFSET ?= 2001
WEB_BASE_HREF ?= /

READ_PUBSPEC_VERSION_SH = app_version=$$(awk '/^version:[[:space:]]*/{sub(/^version:[[:space:]]*/, "", $$0); print; exit}' pubspec.yaml); \
	app_version_name=$$(printf '%s' "$$app_version" | cut -d+ -f1); \
	app_version_code=$$(printf '%s' "$$app_version" | cut -d+ -f2); \
	if [ -z "$$app_version" ] || [ "$$app_version_name" = "$$app_version" ] || [ -z "$$app_version_code" ]; then \
		echo "Unable to parse version from pubspec.yaml (expected name+build)."; \
		exit 1; \
	fi;

NEXT_BUILD_CODE_SH = reference_build_code="$(1)"; \
	next_build_code=$$(( $$(date +%s) + $(ANDROID_BUILD_CODE_OFFSET) )); \
	if [ "$$next_build_code" -le "$$reference_build_code" ]; then \
		next_build_code=$$((reference_build_code + 1)); \
	fi;

# TTY detection: suppress verbose output in non-interactive mode (CI/agents)
ifneq ($(shell test -t 1 && echo yes),yes)
    LOG = /tmp/codewalk-make.log
    QUIET = > $(LOG) 2>&1 || (cat $(LOG) && exit 1)
else ifdef VERBOSE
    QUIET =
else
    QUIET =
endif

help:
	@echo "CodeWalk Make Targets"
	@echo ""
	@echo "  make deps       Install dependencies"
	@echo "  make gen        Run build_runner"
	@echo "  make theme-sync Regenerate OpenCode Web theme registry"
	@echo "  make theme-sync-check  Verify OpenCode Web theme registry is current"
	@echo "  make icons      Regenerate all icons (icons-tray + icons-app)"
	@echo "  make icons-tray Regenerate tray icons from tray_mono_master.png"
	@echo "  make icons-app  Regenerate app icons from original.png"
	@echo "  make tray-prepare  Convert black bg to transparent on tray_mono_master*.png"
	@echo "  make icons-check Validate icon artifacts and dimensions"
	@echo "  make analyze    Run static analysis + issue budget gate"
	@echo "  make test       Run full test suite (parallel)"
	@echo "  make test-fast  Run fast tests only (exclude slow/integration tags)"
	@echo "  make test-unit  Run unit + presentation tests only"
	@echo "  make test-widget  Run widget tests only"
	@echo "  make test-integration  Run integration-tagged tests only"
	@echo "  make test-shard SHARD_TOTAL=N SHARD_INDEX=I  Run one sharded test slice"
	@echo "  make coverage   Run tests with coverage + threshold gate"
	@echo "  make smoke      Run integration smoke test against OpenCode server"
	@echo "  make check      deps + gen + analyze + test"
	@echo "  make check-fast deps + gen + analyze + test-fast"
	@echo "  make web        Build Flutter web app into build/web"
	@echo "  make desktop    Build desktop app for current host OS"
	@echo "  make android    Build Android APK (arm64)"
	@echo "  make precommit  check + android"
	@echo "  make release V=patch|minor|major  Bump version, changelog, commit, tag, push"
	@echo "  make clean      Clean and restore dependencies"

deps:
	flutter pub get $(QUIET)

gen:
	dart run build_runner build --delete-conflicting-outputs $(QUIET)

theme-sync:
	python tool/theme/generate_opencode_web_themes.py $(QUIET)

theme-sync-check:
	python tool/theme/generate_opencode_web_themes.py --check $(QUIET)

icons: icons-tray icons-app

# Convert black background to transparent on tray_mono_master*.png templates.
tray-prepare:
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make tray-prepare."; \
		exit 1; \
	fi
	@for f in assets/images/tray_mono_master*.png; do \
		[ -f "$$f" ] || continue; \
		magick "$$f" -alpha copy -fill white -colorize 100% -resize 512x512\! \
			-strip -define png:compression-level=9 "$$f"; \
		echo "Prepared: $$f"; \
	done

# Derive platform tray icons from fixed tray_mono_master.png template.
icons-tray:
	@if [ ! -f "assets/images/tray_mono_master.png" ]; then \
		echo "Missing fixed tray template: assets/images/tray_mono_master.png"; \
		exit 1; \
	fi
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make icons-tray."; \
		exit 1; \
	fi
	magick assets/images/tray_mono_master.png -resize 48x48\! -strip -define png:compression-level=9 assets/images/tray_icon_linux.png
	magick -size 44x44 xc:black \( assets/images/tray_mono_master.png -resize 44x44\! -alpha extract \) -alpha off -compose CopyOpacity -composite -strip -define png:compression-level=9 assets/images/tray_icon_macos_template.png
	magick assets/images/tray_mono_master.png -resize 64x64\! -define icon:auto-resize=64,48,32,24,20,16 assets/images/tray_icon_windows.ico
	@for size_dir in "drawable-mdpi:24" "drawable-hdpi:36" "drawable-xhdpi:48" "drawable-xxhdpi:72" "drawable-xxxhdpi:96"; do \
		dir=$${size_dir%%:*}; size=$${size_dir##*:}; \
		mkdir -p android/app/src/main/res/$$dir; \
		magick -size $${size}x$${size} xc:white \
			\( assets/images/tray_mono_master.png -resize $${size}x$${size}\! -alpha extract -morphology Dilate Disk:1 \) \
			-alpha off -compose CopyOpacity -composite -strip -define png:compression-level=9 \
			android/app/src/main/res/$$dir/ic_stat_codewalk.png; \
	done
	@echo "Tray icons regenerated."

# Derive app icons from original.png (launcher, adaptive, desktop, web).
icons-app:
	@if [ ! -f "assets/images/original.png" ]; then \
		echo "Missing source image: assets/images/original.png"; \
		exit 1; \
	fi
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make icons-app."; \
		exit 1; \
	fi
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 720x775\! -strip -define png:compression-level=9 assets/images/icon.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 256x256\! -strip -define png:compression-level=9 assets/images/logo.256.png
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 1024x1024\! -strip -define png:compression-level=9 assets/images/logo.1024.png
	magick assets/images/original.png -gravity center -crop 78%x78%+0+0 +repage -resize 1024x1024\! -strip -define png:compression-level=9 assets/images/adaptive_foreground.png
	mkdir -p linux/runner/resources
	magick assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 512x512\! -strip -define png:compression-level=9 \( -size 512x512 xc:none -fill white -draw "roundrectangle 0,0 511,511 72,72" \) -compose CopyOpacity -composite linux/runner/resources/app_icon.png
	cp -f linux/runner/resources/app_icon.png linux/runner/resources/com.verseles.codewalk.png
	printf '%s\n' \
		'[Desktop Entry]' \
		'Version=1.0' \
		'Type=Application' \
		'Name=CodeWalk' \
		'Comment=Cross-platform OpenCode client' \
		'Exec=codewalk %U' \
		'Icon=com.verseles.codewalk' \
		'Terminal=false' \
		'Categories=Development;Utility;' \
		'StartupNotify=true' \
		'StartupWMClass=com.verseles.codewalk' \
		'Keywords=AI;Code;Assistant;OpenCode;' \
		> linux/runner/resources/com.verseles.codewalk.desktop
	magick -size 1024x1024 xc:none \( assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 860x860\! \) -gravity center -composite -define icon:auto-resize=256,128,64,48,32,24,16 windows/runner/resources/app_icon.ico
	# Keep a visual inset on macOS so the launcher icon matches native Dock sizing.
	magick -size 1024x1024 xc:none \
		\( assets/images/original.png -gravity center -crop 84%x84%+0+0 +repage -resize 860x860\! \) \
		-gravity center -composite \
		\( -size 1024x1024 xc:none -fill white -draw "roundrectangle 82,82 941,941 152,152" \) \
		-compose CopyOpacity -composite -strip -define png:compression-level=9 assets/images/macos_appicon_source.png
	magick assets/images/macos_appicon_source.png -resize 16x16\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png
	magick assets/images/macos_appicon_source.png -resize 32x32\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png
	magick assets/images/macos_appicon_source.png -resize 64x64\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png
	magick assets/images/macos_appicon_source.png -resize 128x128\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png
	magick assets/images/macos_appicon_source.png -resize 256x256\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png
	magick assets/images/macos_appicon_source.png -resize 512x512\! -strip -define png:compression-level=9 macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png
	cp -f assets/images/macos_appicon_source.png macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
	dart run flutter_launcher_icons
	# Web maskable icons with safe zone: keep critical subject inside center area.
	magick -size 512x512 xc:'#7EAFC2' \( assets/images/original.png -gravity center -crop 90%x90%+0+0 +repage -resize 420x420\! \) -gravity center -composite -strip -define png:compression-level=9 web/icons/Icon-maskable-512.png
	magick web/icons/Icon-maskable-512.png -resize 192x192\! -strip -define png:compression-level=9 web/icons/Icon-maskable-192.png
	@echo "App icons regenerated."

icons-check:
	@if ! command -v magick >/dev/null 2>&1; then \
		echo "ImageMagick (magick) is required for make icons-check."; \
		exit 1; \
	fi
	@set -e; \
	for f in \
		assets/images/icon.png \
		assets/images/tray_mono_master.png \
		assets/images/tray_icon_linux.png \
		assets/images/tray_icon_macos_template.png \
		assets/images/tray_icon_windows.ico \
		assets/images/macos_appicon_source.png \
		assets/images/adaptive_foreground.png \
		linux/runner/resources/app_icon.png \
		linux/runner/resources/com.verseles.codewalk.png \
		linux/runner/resources/com.verseles.codewalk.desktop \
		windows/runner/resources/app_icon.ico \
		android/app/src/main/res/drawable-mdpi/ic_stat_codewalk.png \
		android/app/src/main/res/drawable-hdpi/ic_stat_codewalk.png \
		android/app/src/main/res/drawable-xhdpi/ic_stat_codewalk.png \
		android/app/src/main/res/drawable-xxhdpi/ic_stat_codewalk.png \
		android/app/src/main/res/drawable-xxxhdpi/ic_stat_codewalk.png \
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
	@test "$$(magick identify -format '%wx%h' assets/images/tray_mono_master.png)" = "512x512" || (echo "Invalid tray mono master size"; exit 1)
	@test "$$(magick identify -format '%wx%h' assets/images/tray_icon_linux.png)" = "48x48" || (echo "Invalid Linux tray icon size"; exit 1)
	@test "$$(magick identify -format '%wx%h' assets/images/tray_icon_macos_template.png)" = "44x44" || (echo "Invalid macOS tray template size"; exit 1)
	@magick identify -format '%[opaque]' assets/images/tray_mono_master.png | grep -qi '^false$$' || (echo "Tray mono master must keep transparency"; exit 1)
	@magick identify -format '%[opaque]' assets/images/tray_icon_linux.png | grep -qi '^false$$' || (echo "Linux tray icon must keep transparency"; exit 1)
	@magick identify -format '%[opaque]' assets/images/tray_icon_macos_template.png | grep -qi '^false$$' || (echo "macOS tray template must keep transparency"; exit 1)
	@test "$$(magick identify -format '%wx%h' assets/images/adaptive_foreground.png)" = "1024x1024" || (echo "Invalid assets/images/adaptive_foreground.png size"; exit 1)
	@test "$$(magick identify -format '%wx%h' linux/runner/resources/app_icon.png)" = "512x512" || (echo "Invalid linux app icon size"; exit 1)
	@test "$$(magick identify -format '%wx%h' linux/runner/resources/com.verseles.codewalk.png)" = "512x512" || (echo "Invalid linux app-id icon size"; exit 1)
	@magick identify -format '%[opaque]' linux/runner/resources/app_icon.png | grep -qi '^false$$' || (echo "Linux app icon must keep rounded transparency"; exit 1)
	@magick identify -format '%[opaque]' linux/runner/resources/com.verseles.codewalk.png | grep -qi '^false$$' || (echo "Linux app-id icon must keep rounded transparency"; exit 1)
	@cmp -s linux/runner/resources/app_icon.png linux/runner/resources/com.verseles.codewalk.png || (echo "Linux icon files must stay in sync"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png)" = "16x16" || (echo "Invalid macOS 16x16 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png)" = "32x32" || (echo "Invalid macOS 32x32 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png)" = "64x64" || (echo "Invalid macOS 64x64 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png)" = "128x128" || (echo "Invalid macOS 128x128 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png)" = "256x256" || (echo "Invalid macOS 256x256 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png)" = "512x512" || (echo "Invalid macOS 512x512 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png)" = "1024x1024" || (echo "Invalid macOS 1024x1024 icon"; exit 1)
	@magick identify -format '%[opaque]' macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png | grep -qi '^false$$' || (echo "macOS launcher icon must include rounded transparency"; exit 1)
	@test "$$(magick identify -format '%wx%h' android/app/src/main/res/drawable-mdpi/ic_stat_codewalk.png)" = "24x24" || (echo "Invalid Android mdpi notification icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' android/app/src/main/res/drawable-hdpi/ic_stat_codewalk.png)" = "36x36" || (echo "Invalid Android hdpi notification icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' android/app/src/main/res/drawable-xhdpi/ic_stat_codewalk.png)" = "48x48" || (echo "Invalid Android xhdpi notification icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' android/app/src/main/res/drawable-xxhdpi/ic_stat_codewalk.png)" = "72x72" || (echo "Invalid Android xxhdpi notification icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' android/app/src/main/res/drawable-xxxhdpi/ic_stat_codewalk.png)" = "96x96" || (echo "Invalid Android xxxhdpi notification icon"; exit 1)
	@magick identify -format '%[opaque]' android/app/src/main/res/drawable-mdpi/ic_stat_codewalk.png | grep -qi '^false$$' || (echo "Android notification icon must keep transparency"; exit 1)
	@test "$$(magick identify -format '%wx%h' web/icons/Icon-maskable-192.png)" = "192x192" || (echo "Invalid web maskable 192 icon"; exit 1)
	@test "$$(magick identify -format '%wx%h' web/icons/Icon-maskable-512.png)" = "512x512" || (echo "Invalid web maskable 512 icon"; exit 1)
	@grep -q '^\[Desktop Entry\]$$' linux/runner/resources/com.verseles.codewalk.desktop || (echo "Missing Desktop Entry header"; exit 1)
	@grep -q '^Type=Application$$' linux/runner/resources/com.verseles.codewalk.desktop || (echo "Desktop entry must be Type=Application"; exit 1)
	@grep -q '^Icon=com\.verseles\.codewalk$$' linux/runner/resources/com.verseles.codewalk.desktop || (echo "Desktop entry icon is not app-id based"; exit 1)
	@grep -q '^Exec=codewalk %U$$' linux/runner/resources/com.verseles.codewalk.desktop || (echo "Desktop entry Exec is unexpected"; exit 1)
	@grep -q '^StartupWMClass=com\.verseles\.codewalk$$' linux/runner/resources/com.verseles.codewalk.desktop || (echo "Desktop entry StartupWMClass mismatch"; exit 1)
	@grep -q 'android:inset="0%"' android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml || (echo "Adaptive icon inset is not 0%"; exit 1)
	@echo "Icon checks passed."

analyze:
	flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee $(ANALYZE_LOG) $(QUIET)
	bash tool/ci/check_analyze_budget.sh $(ANALYZE_LOG) 335

test:
	timeout --foreground 10m flutter test --no-pub --fail-fast $(QUIET)

test-parallel:
	flutter test --no-pub -j $(TEST_JOBS) $(QUIET)

test-fast:
	flutter test --no-pub -j $(TEST_JOBS) --exclude-tags "$(FAST_EXCLUDE_TAGS)" $(QUIET)

test-unit:
	flutter test --no-pub -j $(TEST_JOBS) test/unit test/presentation $(QUIET)

test-widget:
	flutter test --no-pub -j $(TEST_JOBS) test/widget test/widget_test.dart $(QUIET)

test-integration:
	flutter test --no-pub -j 1 --tags integration test/integration $(QUIET)

test-shard:
	@if [ -z "$(SHARD_TOTAL)" ] || [ -z "$(SHARD_INDEX)" ]; then \
		echo "Usage: make test-shard SHARD_TOTAL=<n> SHARD_INDEX=<i>"; \
		exit 1; \
	fi
	flutter test --no-pub -j $(TEST_JOBS) --total-shards $(SHARD_TOTAL) --shard-index $(SHARD_INDEX) $(QUIET)

coverage:
	flutter test --no-pub --coverage -j $(TEST_JOBS) $(QUIET)
	bash tool/ci/check_coverage.sh coverage/lcov.info 35

smoke:
	bash tool/qa/smoke_test.sh

check: deps gen analyze test

check-fast: deps gen analyze test-fast

web:
	flutter build web --release --base-href "$(WEB_BASE_HREF)" $(QUIET)
	@test -f build/web/index.html || (echo "Missing build/web/index.html after web build"; exit 1)
	@test -f build/web/flutter_bootstrap.js || (echo "Missing build/web/flutter_bootstrap.js after web build"; exit 1)
	@echo "Web build ready: build/web/ (base href: $(WEB_BASE_HREF))"

desktop:
	@set -e; \
	$(READ_PUBSPEC_VERSION_SH) \
	if [ "$$OS" = "Windows_NT" ]; then \
		echo "Detected Windows host. Building Windows desktop app..."; \
		flutter build windows --release --build-name "$$app_version_name" --build-number "$$app_version_code"; \
		generated_config="windows/flutter/ephemeral/generated_config.cmake"; \
		if [ ! -f "$$generated_config" ] || ! grep -F "$$app_version_name+$$app_version_code" "$$generated_config" >/dev/null; then \
			echo "Desktop build version mismatch: $$generated_config does not reflect $$app_version_name+$$app_version_code"; \
			exit 1; \
		fi; \
		echo "Desktop build ready: build/windows/x64/runner/Release/"; \
	elif [ "$$(uname -s)" = "Darwin" ]; then \
		echo "Detected macOS host. Building macOS desktop app..."; \
		flutter build macos --release --build-name "$$app_version_name" --build-number "$$app_version_code"; \
		generated_config="macos/Flutter/ephemeral/Flutter-Generated.xcconfig"; \
		if [ ! -f "$$generated_config" ] || ! grep -F "FLUTTER_BUILD_NAME=$$app_version_name" "$$generated_config" >/dev/null || ! grep -F "FLUTTER_BUILD_NUMBER=$$app_version_code" "$$generated_config" >/dev/null; then \
			echo "Desktop build version mismatch: $$generated_config does not reflect $$app_version_name+$$app_version_code"; \
			exit 1; \
		fi; \
		echo "Desktop build ready: build/macos/Build/Products/Release/"; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		echo "Detected Linux host. Building Linux desktop app..."; \
		flutter build linux --release --build-name "$$app_version_name" --build-number "$$app_version_code"; \
		generated_config="linux/flutter/ephemeral/generated_config.cmake"; \
		if [ ! -f "$$generated_config" ] || ! grep -F "$$app_version_name+$$app_version_code" "$$generated_config" >/dev/null; then \
			echo "Desktop build version mismatch: $$generated_config does not reflect $$app_version_name+$$app_version_code"; \
			exit 1; \
		fi; \
		echo "Desktop build ready: build/linux/x64/release/bundle/"; \
	else \
		echo "Unsupported host OS for make desktop."; \
		exit 1; \
	fi

android:
	@if [ ! -f "$(ANDROID_KEY_PROPERTIES)" ]; then \
		echo "Missing $(ANDROID_KEY_PROPERTIES). Refusing to build a debug-signed release APK."; \
		echo "Create $(ANDROID_KEY_PROPERTIES) with keyAlias/keyPassword/storePassword/storeFile before running make android."; \
		exit 1; \
	fi
	@store_file=$$(awk '/^[[:space:]]*storeFile[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/\r/, ""); gsub(/^[[:space:]]+|[[:space:]]+$$/, ""); print; exit}' "$(ANDROID_KEY_PROPERTIES)"); \
	store_password=$$(awk '/^[[:space:]]*storePassword[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/\r/, ""); gsub(/^[[:space:]]+|[[:space:]]+$$/, ""); print; exit}' "$(ANDROID_KEY_PROPERTIES)"); \
	key_password=$$(awk '/^[[:space:]]*keyPassword[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/\r/, ""); gsub(/^[[:space:]]+|[[:space:]]+$$/, ""); print; exit}' "$(ANDROID_KEY_PROPERTIES)"); \
	key_alias=$$(awk '/^[[:space:]]*keyAlias[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/\r/, ""); gsub(/^[[:space:]]+|[[:space:]]+$$/, ""); print; exit}' "$(ANDROID_KEY_PROPERTIES)"); \
	resolved_store_file="$$store_file"; \
	if [ -z "$$store_file" ] || [ -z "$$store_password" ] || [ -z "$$key_password" ] || [ -z "$$key_alias" ]; then \
		echo "Incomplete $(ANDROID_KEY_PROPERTIES). Required keys: storeFile, storePassword, keyPassword, keyAlias."; \
		exit 1; \
	fi; \
	case "$$store_file" in \
		~/*) resolved_store_file="$$HOME/$${store_file#~/}" ;; \
		/*) \
			if [ ! -f "$$resolved_store_file" ]; then \
				home_parent=$$(dirname "$$HOME"); \
				case "$$store_file" in \
					"$$home_parent"/*/*) resolved_store_file="$$HOME/$${store_file#$$home_parent/*/}" ;; \
				esac; \
			fi; \
			;; \
		*) \
			if [ -f "$$HOME/$$store_file" ]; then \
				resolved_store_file="$$HOME/$$store_file"; \
			elif [ -f "$$store_file" ]; then \
				resolved_store_file="$$store_file"; \
			elif [ -f "android/$$store_file" ]; then \
				resolved_store_file="android/$$store_file"; \
			elif [ -f "android/app/$$store_file" ]; then \
				resolved_store_file="android/app/$$store_file"; \
			fi; \
			;; \
	esac; \
	if [ ! -f "$$resolved_store_file" ]; then \
		echo "Keystore declared in $(ANDROID_KEY_PROPERTIES) not found: $$store_file"; \
		echo "Expected one of: $$store_file, $$HOME/$$store_file, android/$$store_file, android/app/$$store_file, or the same path under $$HOME"; \
		exit 1; \
	fi
	@set -e; \
	$(READ_PUBSPEC_VERSION_SH) \
	$(call NEXT_BUILD_CODE_SH,$$app_version_code) \
	test_build_code="$$next_build_code"; \
	flutter build apk --release --target-platform android-arm64 --build-name "$$app_version_name" --build-number "$$test_build_code" $(QUIET); \
	metadata_file="$(APK_METADATA_PATH)"; \
	if [ ! -f "$$metadata_file" ]; then \
		echo "Android build metadata not found: $$metadata_file"; \
		exit 1; \
	fi; \
	metadata_triplet=$$(python3 -c 'import json, sys; data = json.load(open(sys.argv[1])); element = data["elements"][0]; version_code = int(element["versionCode"]); print(f"{element['"'"'versionName'"'"']}|{version_code}|{element['"'"'outputFile'"'"']}")' "$$metadata_file"); \
	metadata_version_name=$${metadata_triplet%%|*}; \
	metadata_rest=$${metadata_triplet#*|}; \
	metadata_version_code=$${metadata_rest%%|*}; \
	metadata_output_file=$${metadata_triplet##*|}; \
	if [ "$$metadata_version_name" != "$$app_version_name" ] || [ "$$metadata_version_code" -lt "$$test_build_code" ]; then \
		echo "Android build version mismatch: expected versionName=$$app_version_name and versionCode at least $$test_build_code but got versionName=$$metadata_version_name outputFile=$$metadata_output_file versionCode=$$metadata_version_code"; \
		exit 1; \
	fi; \
	source_apk="$(APK_DIR)/$$metadata_output_file"; \
	if [ ! -f "$$source_apk" ] && [ -f "$(APK_DIR)/app-release.apk" ]; then \
		source_apk="$(APK_DIR)/app-release.apk"; \
	elif [ ! -f "$$source_apk" ] && [ -f "$(APK_DIR)/app-arm64-v8a-release.apk" ]; then \
		source_apk="$(APK_DIR)/app-arm64-v8a-release.apk"; \
	fi; \
	if [ ! -f "$$source_apk" ]; then \
		echo "APK output not found (expected $$metadata_output_file in $(APK_DIR))"; \
		exit 1; \
	fi; \
	git_ref=$$(git rev-parse --short HEAD 2>/dev/null || echo local); \
	if [ -n "$$(git status --porcelain 2>/dev/null)" ]; then dirty_suffix='-dirty'; else dirty_suffix=''; fi; \
	upload_apk="$(APK_DIR)/codewalk-android-$${app_version_name}+$$metadata_version_code-$$git_ref$$dirty_suffix.apk"; \
	cp -f "$$source_apk" "$(APK_PATH)"; \
	cp -f "$$source_apk" "$$upload_apk"; \
	echo "APK ready (arm64-only): $(APK_PATH)"; \
	echo "APK upload copy: $$upload_apk"; \
	echo "APK Android version: $$app_version_name+$$metadata_version_code"; \
	CAPTION_TEXT="$${HEY_CAPTION:-$$(git log -1 --pretty=%s 2>/dev/null || echo CodeWalk-Android-build)}"; \
	HEY_ALLOW_DUPLICATE=1 HEY_SYNC=1 ~/bin/hey -f "$$upload_apk" "$$CAPTION_TEXT"

precommit: check icons-check android

release:
	@set -e; \
	if [ -z "$(V)" ]; then echo "Usage: make release V=patch|minor|major"; exit 1; fi; \
	if [ -n "$$(git status --porcelain)" ]; then \
		echo "Worktree has pending changes. Commit or resolve them before release."; \
		exit 1; \
	fi; \
	cur_ver=$$(awk '/^version:[[:space:]]*/{sub(/^version:[[:space:]]*/, "", $$0); sub(/\r$$/, "", $$0); split($$0, parts, "+"); print parts[1]; exit}' pubspec.yaml); \
	cur_build=$$(awk '/^version:[[:space:]]*/{sub(/^version:[[:space:]]*/, "", $$0); sub(/\r$$/, "", $$0); split($$0, parts, "+"); if (parts[2] != "") print parts[2]; exit}' pubspec.yaml); \
	if [ -z "$$cur_ver" ] || [ -z "$$cur_build" ]; then echo "Unable to parse version from pubspec.yaml (expected name+build)."; exit 1; fi; \
	major=$$(printf '%s' "$$cur_ver" | cut -d. -f1); \
	minor=$$(printf '%s' "$$cur_ver" | cut -d. -f2); \
	patch=$$(printf '%s' "$$cur_ver" | cut -d. -f3); \
	$(call NEXT_BUILD_CODE_SH,$$cur_build) \
	new_build="$$next_build_code"; \
	case "$(V)" in \
		major) new_ver="$$((major + 1)).0.0" ;; \
		minor) new_ver="$$major.$$((minor + 1)).0" ;; \
		patch) new_ver="$$major.$$minor.$$((patch + 1))" ;; \
		*) echo "V must be patch, minor, or major"; exit 1 ;; \
	esac; \
	echo "$$cur_ver+$$cur_build -> $$new_ver+$$new_build"; \
	python3 tool/release/changelog.py update "$$new_ver"; \
	sed -i "s/^version: .*/version: $$new_ver+$$new_build/" pubspec.yaml; \
	git add pubspec.yaml CHANGELOG.md; \
	git commit -m "release: cut v$$new_ver"; \
	git tag -a "v$$new_ver" -m "v$$new_ver"; \
	git push --follow-tags; \
	echo "Released v$$new_ver — CI and Release workflows triggered."

clean:
	flutter clean
	flutter pub get
