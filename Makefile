.PHONY: generate build install clean sign

BUILD_DIR = .build
APP_NAME = Skimmy
INSTALL_DIR = /Applications

# Code-signing identity.
#
# By default we auto-detect the first "Apple Development" certificate in your
# keychain — so `make install` works on any machine that has an Apple ID signed
# into Xcode, without editing this file.
#
# Override via the environment:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make install
#   SIGN_IDENTITY=<sha1-hash>                                    make install
#   SIGN_IDENTITY=-                                              make install   # ad-hoc / unsigned
#
# List installed identities with:
#   security find-identity -v -p codesigning
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '/Apple Development:/ {print $$2; exit}')

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
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo "error: no Apple Development certificate found in your keychain."; \
		echo "       Install one via Xcode → Settings → Accounts → [+] → Apple ID,"; \
		echo "       then let Xcode create a development certificate for your team."; \
		echo ""; \
		echo "       Alternatively, override the identity explicitly:"; \
		echo "         SIGN_IDENTITY=\"<full-name-or-sha1>\" make install"; \
		echo "       Or build unsigned (Gatekeeper will warn on every open):"; \
		echo "         SIGN_IDENTITY=- make install"; \
		exit 1; \
	fi
	@echo "Signing $(INSTALL_DIR)/$(APP_NAME).app with: $(SIGN_IDENTITY)"
	codesign --force --deep --sign "$(SIGN_IDENTITY)" \
		--options runtime \
		--timestamp=none \
		"$(INSTALL_DIR)/$(APP_NAME).app"
	@codesign -dv --verbose=2 "$(INSTALL_DIR)/$(APP_NAME).app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier" || true

clean:
	rm -rf $(BUILD_DIR) $(APP_NAME).xcodeproj
