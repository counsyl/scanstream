all:
	xcodebuild -workspace ScanStream.xcworkspace -scheme ScanStream -configuration Release $(EXTRA_XCODEBUILD_FLAGS)
