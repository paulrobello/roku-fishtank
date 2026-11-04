ZIP := dist/channel.zip
BIN := node_modules/.bin
BRS_GLOBS := "source/**/*.brs" "components/**/*.brs"
SHELL := /bin/bash

.PHONY: install build fmt fmt-check lint typecheck test checkall checkall-ci deploy art clean

install: node_modules

node_modules: package.json bun.lock
	bun install --frozen-lockfile
	@touch node_modules

# Device package: bsc validates, transpiles to dist/staging and zips it.
build: node_modules
	@mkdir -p dist
	@rm -f $(ZIP)
	$(BIN)/bsc --project bsconfig.json --create-package --out-file $(ZIP) > dist/bsc-build.log 2>&1 || { cat dist/bsc-build.log; exit 1; }
	@unzip -l $(ZIP) | grep -qE " manifest$$" || { echo "zip missing manifest"; exit 1; }
	@unzip -l $(ZIP) | grep -qE " source/main\.brs$$" || { echo "zip missing source/main.brs"; exit 1; }
	@echo "built $(ZIP)"

fmt: node_modules
	$(BIN)/bsfmt $(BRS_GLOBS) --write

fmt-check: node_modules
	$(BIN)/bsfmt $(BRS_GLOBS) --check

# bslint only; any warning fails the gate.
lint: node_modules
	@mkdir -p dist
	@$(BIN)/bslint --project bsconfig.json > dist/bslint.log 2>&1; ec=$$?; \
	  grep -E " - (error|warning) " dist/bslint.log; \
	  if [ $$ec -ne 0 ] || grep -qE " - (error|warning) " dist/bslint.log; then echo "lint FAILED"; exit 1; fi; \
	  echo "lint ok"

# bsc validate (types, scopes, missing functions); any warning fails the gate.
typecheck: node_modules
	@mkdir -p dist
	@$(BIN)/bsc --project bsconfig.json > dist/bsc.log 2>&1; ec=$$?; \
	  grep -E " - (error|warning) " dist/bsc.log; \
	  if [ $$ec -ne 0 ] || grep -qE " - (error|warning) " dist/bsc.log; then echo "typecheck FAILED"; exit 1; fi; \
	  echo "typecheck ok"

# BrightScript unit tests under brs-cli. The runner throws when any test fails,
# which makes brs-cli exit 1.
test: node_modules
	$(BIN)/brs-cli tests/run_tests.brs tests/lib/*.brs tests/unit/*.brs components/lib/*.brs

# Fast gate, ordered cheapest first. No CI exists, so checkall-ci is the same gate.
checkall: api-guard fmt-check lint typecheck test build zip-check
	@echo "checkall OK"

checkall-ci: checkall

.PHONY: api-guard zip-check

# OS 16.0-only APIs, Main/RunUserInterface and manifest title= in device sources.
api-guard:
	@bash tools/api_guard.sh

# Device zip holds only manifest, source/, components/, images/, config/.
zip-check: build
	@bash tools/zip_check.sh $(ZIP)

# Exit the screensaver on the TV before deploying: deploying under a running
# instance wedges it until a device reboot.
# ROKU_HOST=<ip> ROKU_PASSWORD=<dev password> make deploy
deploy: build
	curl -sS -f --digest --user rokudev:$(ROKU_PASSWORD) -F "mysubmit=1" -F "archive=@$(ZIP)" "http://$(ROKU_HOST)/plugin_install"

art:
	python3 tools/make_art.py

clean:
	rm -rf dist
