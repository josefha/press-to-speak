APP_DIR := apps/mac

.PHONY: run build package-app release-artifacts notarized-release install-local clean mac-help api-docs

run:
	$(MAKE) -C $(APP_DIR) run

build:
	$(MAKE) -C $(APP_DIR) build

package-app:
	$(MAKE) -C $(APP_DIR) package-app

release-artifacts:
	$(MAKE) -C $(APP_DIR) release-artifacts

notarized-release:
	$(MAKE) -C $(APP_DIR) notarized-release

install-local:
	$(MAKE) -C $(APP_DIR) install-local

clean:
	$(MAKE) -C $(APP_DIR) clean

mac-help:
	@echo "macOS app lives in apps/mac"
	@echo "Use make run/build/install-local from repo root (forwarded)."

api-docs:
	@echo "API is docs-only right now. See apps/api/README.md and apps/api/docs/architecture.md"
