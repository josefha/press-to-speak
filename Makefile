MAC_APP_DIR := apps/mac
API_APP_DIR := apps/api

.PHONY: run build package-app release-artifacts notarized-release install-local clean mac-help api-docs api-install api-dev api-build api-typecheck

run:
	$(MAKE) -C $(MAC_APP_DIR) run

build:
	$(MAKE) -C $(MAC_APP_DIR) build

package-app:
	$(MAKE) -C $(MAC_APP_DIR) package-app

release-artifacts:
	$(MAKE) -C $(MAC_APP_DIR) release-artifacts

notarized-release:
	$(MAKE) -C $(MAC_APP_DIR) notarized-release

install-local:
	$(MAKE) -C $(MAC_APP_DIR) install-local

clean:
	$(MAKE) -C $(MAC_APP_DIR) clean

mac-help:
	@echo "macOS app lives in apps/mac"
	@echo "Use make run/build/install-local from repo root (forwarded)."

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
