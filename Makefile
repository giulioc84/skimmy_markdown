.PHONY: generate build install clean sign notarize release

BUILD_DIR = .build
APP_NAME = Skimmy
INSTALL_DIR = /Applications

# -----------------------------------------------------------------------------
# Code-signing identity
# -----------------------------------------------------------------------------
# Auto-detect, preferring a Developer ID Application cert (distribution-grade,
# Gatekeeper-accepted, notarizable) over an Apple Development cert (local dev
# only). Override via environment:
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make install
#   SIGN_IDENTITY=<sha1-hash>                                    make install
#   SIGN_IDENTITY=-                                              make install   # ad-hoc / unsigned
#
# List installed identities with:
#   security find-identity -v -p codesigning
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk -F'"' '\
	/Developer ID Application:/ {devid = $$2} \
	/Apple Development:/         {appdev = $$2} \
	END { if (devid) print devid; else if (appdev) print appdev }')

# -----------------------------------------------------------------------------
# Notarization (optional, only meaningful with a Developer ID cert)
# -----------------------------------------------------------------------------
# `make notarize` expects a keychain profile created once via:
#   xcrun notarytool store-credentials "$(NOTARY_PROFILE)" \
#       --apple-id "you@example.com" \
#       --team-id  "TEAMID" \
#       --password "app-specific-password"
NOTARY_PROFILE ?= SKIMMY_NOTARY
NOTARIZE_ZIP    = /tmp/$(APP_NAME)-notarize.zip

# -----------------------------------------------------------------------------
# Release
# -----------------------------------------------------------------------------
# `make release`                  — uses the version in project.yml
# `make release VERSION=1.0.1`    — bumps project.yml first, then releases
#
# Produces `dist/$(APP_NAME)-<version>.zip` — signed, notarized, stapled,
# ready to upload to your website.
DIST_DIR = dist

# -----------------------------------------------------------------------------
# Targets
# -----------------------------------------------------------------------------

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
		echo "error: no signing certificate found in your keychain."; \
		echo "       Install one via Xcode → Settings → Accounts → Manage Certificates,"; \
		echo "       or override with: SIGN_IDENTITY=\"<full-name-or-sha1>\" make install"; \
		echo "       Build unsigned (ad-hoc) with: SIGN_IDENTITY=- make install"; \
		exit 1; \
	fi
	@echo "Signing $(INSTALL_DIR)/$(APP_NAME).app with: $(SIGN_IDENTITY)"
	@# --timestamp (with a real RFC3161 server) is REQUIRED for notarization.
	@# --options runtime enables the hardened runtime, also required.
	codesign --force --deep --sign "$(SIGN_IDENTITY)" \
		--options runtime \
		--timestamp \
		"$(INSTALL_DIR)/$(APP_NAME).app"
	@codesign -dv --verbose=2 "$(INSTALL_DIR)/$(APP_NAME).app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier" || true

# Notarize the currently-installed app and staple the ticket.
# Requires: 1) a Developer ID Application cert, 2) a `NOTARY_PROFILE` created
# via `xcrun notarytool store-credentials` (see README).
notarize:
	@case "$(SIGN_IDENTITY)" in \
		"Developer ID Application:"*) ;; \
		*) echo "error: notarization requires a 'Developer ID Application' certificate."; \
		   echo "       Current SIGN_IDENTITY is: $(SIGN_IDENTITY)"; \
		   echo "       Create one via Xcode → Settings → Accounts → Manage Certificates."; \
		   exit 1 ;; \
	esac
	@if ! xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" >/dev/null 2>&1; then \
		echo "error: notarytool profile '$(NOTARY_PROFILE)' not found in keychain."; \
		echo "       Create it once with:"; \
		echo "         xcrun notarytool store-credentials \"$(NOTARY_PROFILE)\" \\"; \
		echo "           --apple-id \"you@example.com\" \\"; \
		echo "           --team-id  \"TEAMID\" \\"; \
		echo "           --password \"app-specific-password\""; \
		echo "       Generate the app-specific password at https://appleid.apple.com/account/manage"; \
		exit 1; \
	fi
	@echo "Zipping $(APP_NAME).app for submission…"
	/usr/bin/ditto -c -k --keepParent "$(INSTALL_DIR)/$(APP_NAME).app" "$(NOTARIZE_ZIP)"
	@echo "Submitting to Apple's notarization service (takes 1–5 minutes)…"
	xcrun notarytool submit "$(NOTARIZE_ZIP)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	@echo "Stapling ticket…"
	xcrun stapler staple "$(INSTALL_DIR)/$(APP_NAME).app"
	xcrun stapler validate "$(INSTALL_DIR)/$(APP_NAME).app"
	@rm -f "$(NOTARIZE_ZIP)"
	@echo "$(APP_NAME) is signed, notarized, and stapled. Gatekeeper will accept it on any Mac."

# Build + sign + notarize + staple + zip, producing a distributable artifact
# under dist/. Pass VERSION=x.y.z to bump project.yml first.
release:
	@# If VERSION was passed, validate and apply it to project.yml BEFORE building.
	@if [ -n "$(VERSION)" ]; then \
		if ! echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$'; then \
			echo "error: VERSION must be SemVer (MAJOR.MINOR.PATCH). Got: $(VERSION)"; \
			exit 1; \
		fi; \
		echo "Bumping project.yml → $(VERSION)"; \
		sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "$(VERSION)"/' project.yml; \
		sed -i '' 's/CURRENT_PROJECT_VERSION: ".*"/CURRENT_PROJECT_VERSION: "$(VERSION)"/' project.yml; \
	fi
	@$(MAKE) install
	@$(MAKE) notarize
	@mkdir -p $(DIST_DIR)
	@RELEASE_VERSION=$$(awk '/MARKETING_VERSION:/ {gsub(/"/,""); print $$2}' project.yml); \
	  ZIP="$(DIST_DIR)/$(APP_NAME).zip"; \
	  rm -f "$$ZIP"; \
	  /usr/bin/ditto -c -k --keepParent "$(INSTALL_DIR)/$(APP_NAME).app" "$$ZIP"; \
	  SIZE=$$(ls -lh "$$ZIP" | awk '{print $$5}'); \
	  echo ""; \
	  echo "✅ Release artifact ready: $$ZIP ($$SIZE)"; \
	  echo "   Stable filename — the 'latest download' URL on your website keeps working across versions."; \
	  echo ""; \
	  echo "Suggested next steps:"; \
	  echo "   1. Move CHANGELOG.md [Unreleased] entries under [$$RELEASE_VERSION] - $$(date +%Y-%m-%d)"; \
	  echo "   2. git commit -am \"Release $$RELEASE_VERSION\""; \
	  echo "   3. git tag -a v$$RELEASE_VERSION -m \"Skimmy $$RELEASE_VERSION\""; \
	  echo "   4. git push origin main v$$RELEASE_VERSION"; \
	  echo "   5. gh release create v$$RELEASE_VERSION \"$$ZIP\" --title \"Skimmy $$RELEASE_VERSION\" --notes-file CHANGELOG.md"

clean:
	rm -rf $(BUILD_DIR) $(APP_NAME).xcodeproj $(DIST_DIR)
