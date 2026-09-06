.PHONY: generate test ci-local build versions

SIMULATOR_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

generate:
	xcodegen generate

build: generate
	xcodebuild -project Fazendinha.xcodeproj -scheme Fazendinha -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project Fazendinha.xcodeproj -scheme Fazendinha -destination '$(SIMULATOR_DESTINATION)' CODE_SIGNING_ALLOWED=NO test

versions:
	xcodebuild -version
	swift --version
	xcodegen --version

# Mirrors the GitHub Actions test command without consuming hosted CI minutes.
ci-local: versions test
