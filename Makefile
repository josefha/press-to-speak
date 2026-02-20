APP_NAME := PressToSpeak
PRODUCT := PressToSpeakApp

.PHONY: run build package-app install-local clean

run:
	swift run $(PRODUCT)

build:
	swift build -c release --product $(PRODUCT)

package-app: build
	./scripts/package_app.sh

install-local: package-app
	@if [ -d /Applications/$(APP_NAME).app ]; then \
		ditto dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	else \
		cp -R dist/$(APP_NAME).app /Applications/$(APP_NAME).app; \
	fi
	@echo "Installed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build dist
