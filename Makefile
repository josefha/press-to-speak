MAC_APP_DIR := apps/mac
API_APP_DIR := apps/api

.PHONY: run build package-app release-artifacts notarized-release install-local clean \
	mac-run mac-build-binary mac-build-app mac-install-app mac-open-app mac-install-and-open mac-help \
	api-docs api-install api-dev api-build api-typecheck

run: mac-run

build: mac-build-binary

package-app: mac-build-app

install-local: mac-install-app

mac-run:
	$(MAKE) -C $(MAC_APP_DIR) run

mac-build-binary:
	$(MAKE) -C $(MAC_APP_DIR) build

mac-build-app:
	$(MAKE) -C $(MAC_APP_DIR) package-app

release-artifacts:
	$(MAKE) -C $(MAC_APP_DIR) release-artifacts

notarized-release:
	$(MAKE) -C $(MAC_APP_DIR) notarized-release

mac-install-app:
	$(MAKE) -C $(MAC_APP_DIR) install-local

mac-open-app:
	$(MAKE) -C $(MAC_APP_DIR) open-app

mac-install-and-open: mac-install-app mac-open-app

clean:
	$(MAKE) -C $(MAC_APP_DIR) clean

mac-help:
	@echo "macOS app lives in apps/mac"
	@echo "make mac-run              # run from SwiftPM (no install)"
	@echo "make mac-build-binary     # compile release binary"
	@echo "make mac-build-app        # package .app to apps/mac/dist"
	@echo "make mac-install-app      # install to /Applications/PressToSpeak.app"
	@echo "make mac-open-app         # open /Applications/PressToSpeak.app"
	@echo "make mac-install-and-open # install then open"
	@echo "Legacy aliases still work: make run/build/package-app/install-local"

api-docs:
	@echo "API docs: apps/api/README.md and apps/api/docs/architecture.md"

api-install:
	cd $(API_APP_DIR) && npm install

api-dev:
	cd $(API_APP_DIR) && npm run dev

api-build:
	cd $(API_APP_DIR) && npm run build

api-typecheck:
	cd $(API_APP_DIR) && npm run typecheck
