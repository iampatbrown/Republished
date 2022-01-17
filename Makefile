PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p)
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 4 - 44mm

test:
	xcodebuild test \
		-scheme Republished \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme Republished \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme Republished \
		-destination platform="$(PLATFORM_TVOS)"
	xcodebuild \
		-scheme Republished \
		-destination platform="$(PLATFORM_WATCHOS)"
