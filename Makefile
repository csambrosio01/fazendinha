.PHONY: generate test ci-local build

generate:
	xcodegen generate

build: generate
	xcodebuild -project Fazendinha.xcodeproj -scheme Fazendinha -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild -project Fazendinha.xcodeproj -scheme Fazendinha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test

# Mirrors the GitHub Actions test command without consuming hosted CI minutes.
ci-local: test
