# Swift Testing needs a framework path this machine does not supply by default.
#
# `xcode-select -p` points at Xcode.app, so `xcodebuild` and `swift build` are
# fine. But `xcrun -f swift` still resolves to
# /Library/Developer/CommandLineTools/usr/bin/swift, and THAT swiftpm knows
# nothing about Testing.framework, which ships inside Xcode's MacOSX platform
# rather than the toolchain. So a bare `swift test` fails twice over:
#
#   compile:  error: no such module 'Testing'
#   run:      Library not loaded: @rpath/Testing.framework/Versions/A/Testing
#
# -F puts it on the compile search path, -rpath lets the built bundle find it,
# and DYLD_FRAMEWORK_PATH covers the helper process that actually dlopens it.
# All three are needed; any two leave one of the failures above.
#
# Encoded here rather than written down somewhere, so `make test` just works.

# Hardcoded, NOT $(shell xcode-select -p): that returns
# /Library/Developer/CommandLineTools on this machine, and make does not
# inherit a DEVELOPER_DIR exported by the calling shell anyway.
DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
TESTING_FW := $(DEVELOPER_DIR)/Platforms/MacOSX.platform/Developer/Library/Frameworks

.PHONY: build test regenerate clean

build:
	swift build

test:
	DYLD_FRAMEWORK_PATH="$(TESTING_FW)" swift test \
		-Xswiftc -F -Xswiftc "$(TESTING_FW)" \
		-Xlinker -rpath -Xlinker "$(TESTING_FW)"

# The spec is the source of truth and lives in the SERVER repo, where a
# guardrail keeps it in step with the routes. Copy, never hand-edit.
regenerate:
	cp ../playerz.bg/openapi/playerz-v1.json Sources/PlayerzAPI/openapi.json
	swift build

clean:
	rm -rf .build
