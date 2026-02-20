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
	rm -rf /Applications/$(APP_NAME).app
	cp -R dist/$(APP_NAME).app /Applications/$(APP_NAME).app
	@echo "Installed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build dist
