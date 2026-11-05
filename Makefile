.PHONY: help deps icons icons-tray icons-app tray-prepare icons-check analyze test test-parallel test-fast test-coverage-tools test-v2-tools test-release-tools test-shard coverage check check-fast v2-architecture v2-foundations v2-native-check v2-linux-debug v2-android-debug v2-smoke v2-web clean release watch-ci watch-release

.PHONY: v2-linux-preview-package v2-linux-preview-smoke v2-android-preview
ANALYZE_LOG = /tmp/flutter_analyze.log
TEST_JOBS ?= 4
TEST_TIMEOUT ?= 10m
FAST_EXCLUDE_TAGS ?= slow,integration
# The Linux preview architecture follows the build host.
V2_LINUX_ARCH ?= $(if $(filter aarch64 arm64,$(shell uname -m)),arm64,x64)

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
	@echo "  make icons      Regenerate all icons (icons-tray + icons-app)"
	@echo "  make icons-tray Regenerate tray icons from tray_mono_master.png"
	@echo "  make icons-app  Regenerate app icons from original.png"
	@echo "  make tray-prepare  Convert black bg to transparent on tray_mono_master*.png"
	@echo "  make icons-check Validate icon artifacts and dimensions"
	@echo "  make analyze    Run static analysis + issue budget gate"
	@echo "  make test       Run full test suite (parallel)"
	@echo "  make test-fast  Run fast tests only (exclude slow/integration tags)"
	@echo "  make test-coverage-tools  Verify LCOV filtering and coverage gates"
	@echo "  make test-release-tools  Verify the v2 beta release plan, guards and tooling"
	@echo "  make test-shard SHARD_TOTAL=N SHARD_INDEX=I  Run one sharded test slice"
	@echo "  make coverage   Run tests with coverage + threshold gate"
	@echo "  make check      deps + analyze + coverage-tool fixtures + test"
	@echo "  make check-fast deps + analyze + coverage-tool fixtures + test-fast"
	@echo "  make v2-architecture Check the governed v2 surface"
	@echo "  make v2-foundations Discover/check every v2 package, guards, bootstrap and Web build"
	@echo "  make v2-native-check Discover/check v2 packages and VM/CHP tests without a browser"
	@echo "  make v2-linux-debug Compile main_v2.dart for this Linux host (fresh native outputs)"
	@echo "  make v2-linux-preview-package Package an isolated Linux development preview (host arch)"
	@echo "  make v2-linux-preview-smoke Verify the exact packaged preview under Xvfb"
	@echo "  make v2-android-debug Compile main_v2.dart for Android arm64 on an x64 host"
	@echo "  make v2-android-preview Build the owner preview APK (profile, beside v1) on an x64 host"
	@echo "  make v2-smoke   Exercise the explicit v2 entry point in widget tests"
	@echo "  make v2-web     Build the explicit v2 entry point into build/v2/web"
	@echo "  make release V=beta  Cut the next v2.0.0-beta.N on main (DRY_RUN=1 prints the plan only)"
	@echo "    stable, patch and v1 releases are cut on the v1 branch"
	@echo "  make clean      Clean and restore dependencies"

deps:
	flutter pub get $(QUIET)

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
	bash tool/ci/check_analyze_budget.sh $(ANALYZE_LOG) 4

test:
	timeout --verbose --foreground $(TEST_TIMEOUT) flutter test --no-pub -j $(TEST_JOBS) --fail-fast $(QUIET)

test-parallel:
	flutter test --no-pub -j $(TEST_JOBS) $(QUIET)

test-fast:
	flutter test --no-pub -j $(TEST_JOBS) --exclude-tags "$(FAST_EXCLUDE_TAGS)" $(QUIET)

test-coverage-tools:
	python3 -m unittest discover -s tool/ci -p test_check_coverage.py $(QUIET)

test-v2-tools:
	python3 -m unittest discover -s tool/ci -p 'test_*v2*.py' $(QUIET)

test-release-tools:
	python3 -m unittest discover -s tool/release -p 'test_*.py' $(QUIET)

test-shard:
	@if [ -z "$(SHARD_TOTAL)" ] || [ -z "$(SHARD_INDEX)" ]; then \
		echo "Usage: make test-shard SHARD_TOTAL=<n> SHARD_INDEX=<i>"; \
		exit 1; \
	fi
	flutter test --no-pub -j $(TEST_JOBS) --total-shards $(SHARD_TOTAL) --shard-index $(SHARD_INDEX) $(QUIET)

coverage:
	flutter test --no-pub --coverage -j $(TEST_JOBS) $(QUIET)
	bash tool/ci/check_coverage.sh coverage/lcov.info 85

check: deps analyze test-coverage-tools test-v2-tools test-release-tools test

check-fast: deps analyze test-coverage-tools test-fast

# Coexistence: check/check-fast retain the reference suite. These targets
# explicitly select the active v2 surface; 020CA owns the native MVP aggregate,
# while 020C retains full-platform acceptance.
v2-architecture:
	dart run tool/ci/import_rules.dart

v2-foundations:
	python3 tool/ci/check_v2_foundations.py

v2-native-check: test-v2-tools
	python3 tool/ci/check_v2_foundations.py --profile native

v2-linux-debug:
	python3 tool/ci/build_v2_native.py linux

v2-linux-preview-package:
	python3 tool/preview/preview_linux.py package --bundle build/linux/$(V2_LINUX_ARCH)/debug/bundle --metadata build/native-evidence/linux.json --output build/native-evidence/codewalk-v2-preview-linux-$(V2_LINUX_ARCH).tar.gz

v2-linux-preview-smoke:
	python3 tool/ci/smoke_v2_linux_preview.py --archive build/native-evidence/codewalk-v2-preview-linux-$(V2_LINUX_ARCH).tar.gz --evidence build/native-evidence/preview-smoke

v2-android-debug:
	python3 tool/ci/build_v2_native.py android

v2-android-preview:
	python3 tool/ci/build_v2_native.py android-preview

v2-smoke:
	flutter test --no-pub test/v2

v2-web:
	flutter build web --no-pub --target lib/main_v2.dart --output build/v2/web

# main cuts only v2 betas; stable, patch and v1 releases come from the v1 branch.
# Detached and agentless: reports through hey, so no agent watches CI (see AGENTS.md).
watch-ci:
	@setsid nohup bash tool/ci/notify_run.sh ci.yml failures >/dev/null 2>&1 < /dev/null &

watch-release:
	@setsid nohup bash tool/ci/notify_run.sh release.yml always >/dev/null 2>&1 < /dev/null &

release:
	@if [ "$(V)" != "beta" ]; then \
		echo "main releases only v2 betas: make release V=beta [DRY_RUN=1]. Cut stable, patch and v1 releases on the v1 branch."; \
		exit 1; \
	fi
	python3 tool/release/cut_beta.py $(if $(filter 1,$(DRY_RUN)),--dry-run,)

clean:
	flutter clean
	flutter pub get
