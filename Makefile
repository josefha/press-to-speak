APP_NAME := PressToSpeak
PRODUCT := PressToSpeakApp
CODESIGN_IDENTITY ?= Apple Development: Your Name Josef Karakoca
NOTARY_PROFILE ?=

.PHONY: run build package-app release-artifacts notarized-release install-local clean

run:
	swift run $(PRODUCT)

build:
	swift build -c release --product $(PRODUCT)

package-app: build
	CODESIGN_IDENTITY="$(CODESIGN_IDENTITY)" ./scripts/package_app.sh

release-artifacts: package-app
	./scripts/build_release_artifacts.sh

notarized-release: release-artifacts
	NOTARY_PROFILE="$(NOTARY_PROFILE)" ./scripts/notarize_dmg.sh

install-local: package-app
	@if [ -d /Applications/$(APP_NAME).app ]; then \
		ditto dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	else \
		cp -R dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	fi
	@echo "Installed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build dist
