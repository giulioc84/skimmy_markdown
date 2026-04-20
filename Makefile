.PHONY: generate build install clean sign

BUILD_DIR = .build
APP_NAME = Skimmy
INSTALL_DIR = /Applications

# Apple Development certificate SHA-1 hash for code signing.
# Get with: security find-identity -v -p codesigning
SIGN_IDENTITY = 0352EC6FC385D5F028F8D600400F7E554340D963

generate:
	xcodegen generate

build: generate
	xcodebuild \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=YES \
		build

install: build
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_DIR)/"
	@$(MAKE) sign
	@echo "Installed $(APP_NAME) to $(INSTALL_DIR)"

sign:
	@echo "Signing $(INSTALL_DIR)/$(APP_NAME).app with Apple Development certificate..."
	codesign --force --deep --sign $(SIGN_IDENTITY) \
		--options runtime \
		--timestamp=none \
		"$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Signature:"
	@codesign -dv --verbose=2 "$(INSTALL_DIR)/$(APP_NAME).app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier"

clean:
	rm -rf $(BUILD_DIR) $(APP_NAME).xcodeproj
