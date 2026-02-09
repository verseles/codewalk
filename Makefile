.PHONY: precommit analyze test build-runner clean

precommit: analyze test

analyze:
	flutter analyze

test:
	flutter test

build-runner:
	dart run build_runner build --delete-conflicting-outputs

clean:
	flutter clean
	flutter pub get
