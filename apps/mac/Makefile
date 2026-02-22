APP_NAME := PressToSpeak
PRODUCT := PressToSpeakApp
CODESIGN_IDENTITY ?= Apple Development: Your Name Josef Karakoca
NOTARY_PROFILE ?=
PRODUCTION_ENV_FILE ?= .env.production
PRODUCTION_PROXY_URL ?=
PRODUCTION_CODESIGN_IDENTITY ?=

.PHONY: run build package-app release-artifacts production-export notarized-release install-local open-app install-and-open clean

run:
	swift run $(PRODUCT)

build:
	swift build -c release --product $(PRODUCT)

package-app: build
	CODESIGN_IDENTITY="$(CODESIGN_IDENTITY)" ./scripts/package_app.sh

release-artifacts: package-app
	./scripts/build_release_artifacts.sh

production-export:
	PRODUCTION_ENV_FILE="$(PRODUCTION_ENV_FILE)" PRODUCTION_PROXY_URL="$(PRODUCTION_PROXY_URL)" CODESIGN_IDENTITY="$(PRODUCTION_CODESIGN_IDENTITY)" ./scripts/build_production_release.sh

notarized-release: release-artifacts
	NOTARY_PROFILE="$(NOTARY_PROFILE)" ./scripts/notarize_dmg.sh

install-local: package-app
	@if [ -d /Applications/$(APP_NAME).app ]; then \
		ditto dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	else \
		cp -R dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	fi
	@echo "Installed /Applications/$(APP_NAME).app"

open-app:
	@if [ -d /Applications/$(APP_NAME).app ]; then \
		open /Applications/$(APP_NAME).app; \
	else \
		echo "Missing /Applications/$(APP_NAME).app. Run 'make install-local' first."; \
		exit 1; \
	fi

install-and-open: install-local open-app

clean:
	rm -rf .build dist
