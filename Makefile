ZIP := dist/channel.zip
FIDELITY_ZIP := dist/fidelity.zip
BIN := node_modules/.bin
BRS_GLOBS := "source/**/*.brs" "components/**/*.brs" "fidelity/**/*.brs"
SHELL := /bin/bash

# Gitignored ROKU_HOST / ROKU_PASSWORD for the device targets.
-include .env
ROKU_HOST ?= 192.168.1.10
export ROKU_HOST ROKU_PASSWORD

.PHONY: install build fmt fmt-check lint typecheck test checkall checkall-ci deploy art clean
.PHONY: dev dev-start dev-stop dev-restart test-visual
.PHONY: probe probe-build check-build device-check

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
	$(BIN)/brs-cli tests/run_tests.brs tests/lib/*.brs tests/unit/*.brs components/lib/*.brs source/preview_color.brs

# Fast gate, ordered cheapest first. No CI exists, so checkall-ci is the same gate.
checkall: api-guard fmt-check lint typecheck test build zip-check fidelity-build test-visual
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

# Device perf probe (P0.6): ramps fish/layer counts, logs fps + texture use.
probe-build: node_modules
	@mkdir -p dist
	@rm -f dist/probe.zip
	$(BIN)/bsc --project bsconfig.probe.json --create-package --out-file dist/probe.zip > dist/bsc-probe.log 2>&1 || { cat dist/bsc-probe.log; exit 1; }

probe: probe-build
	tools/perf/run_probe.sh docs/perf/raw

# Device check: any channel scene as the screensaver plus an FpsMeter on the console.
# make device-check SCENE=BrainDemoScene SECONDS=90 -> docs/perf/raw/check-<scene>-<stamp>-*
# DENSITY=calm|normal|busy picks the ReefTank population (empty = the scene default).
SCENE ?= ReefTank
SECONDS ?= 90
DENSITY ?=
check-build: node_modules
	@mkdir -p dist
	@rm -f dist/check.zip
	@printf '{"scene": "%s", "density": "%s"}\n' "$(SCENE)" "$(DENSITY)" > dist/devicecheck.json
	@$(BIN)/bsc --project bsconfig.check.json --create-package --out-file dist/check.zip > dist/bsc-check.log 2>&1; ec=$$?; \
	  if [ $$ec -ne 0 ] || grep -qE " - (error|warning) " dist/bsc-check.log; then cat dist/bsc-check.log; echo "check-build FAILED"; exit 1; fi
	@echo "built dist/check.zip ($(SCENE))"

device-check: check-build
	bash tools/devicecheck/run.sh dist/check.zip docs/perf/raw/check-$(SCENE)-$$(date +%Y%m%d-%H%M%S) $(SECONDS)

# Rig pipeline: approved cutouts in assets/source/ -> images/fish, images/decor,
# config/species/*.rig.json and docs/art/rig-check-*.png (byte-reproducible).
art:
	uv run tools/art/rig.py

# Placeholder fish sprites (images/fish_orange.png, fish_blue.png) for the P1.5 lane fish.
.PHONY: art-placeholder
art-placeholder:
	python3 tools/make_art.py

# Icon and splash art from the reef backdrop, scene.json decor and fish rigs (byte-reproducible).
.PHONY: key-art
key-art:
	uv run tools/art/key_art.py

# Bubble sprite and seaweed segments for P1.3/P1.4 (byte-reproducible).
.PHONY: ambient-art
ambient-art:
	uv run tools/art/bubble.py
	uv run tools/art/seaweed.py

# Browser preview (brs-engine) on 8138. The channel zip is rebuilt from source on every page load.
PREVIEW_PORT := 8138

dev: node_modules
	bunx --bun vite --config preview/vite.config.ts --port $(PREVIEW_PORT) --strictPort

dev-start: dev

dev-stop:
	@pids=$$(lsof -ti tcp:$(PREVIEW_PORT) -sTCP:LISTEN); [ -z "$$pids" ] || kill $$pids; \
	  for i in $$(seq 1 40); do lsof -ti tcp:$(PREVIEW_PORT) -sTCP:LISTEN >/dev/null || exit 0; sleep 0.25; done; \
	  echo "port $(PREVIEW_PORT) still busy"; exit 1

dev-restart: dev-stop dev

# Screenshot gate: Playwright serves its own preview on 8139, freezes the scene and
# compares the canvas to tests/visual/__screenshots__/.
test-visual: node_modules
	@mkdir -p dist
	@bunx playwright install chromium > dist/playwright-install.log 2>&1 || { cat dist/playwright-install.log; exit 1; }
	bunx playwright test

.PHONY: fidelity-build fidelity-device fidelity-sim

# Fidelity device package (P0.5): FidelityScene as the screensaver. bsc with bslint
# validates it (FidelityScene is excluded from bsconfig.json, so this leg is its
# lint/typecheck); any warning fails, then zip-check runs on the package.
fidelity-build: node_modules
	@mkdir -p dist
	@rm -f $(FIDELITY_ZIP)
	@$(BIN)/bsc --project bsconfig.fidelity.json --create-package --out-file $(FIDELITY_ZIP) > dist/bsc-fidelity.log 2>&1; ec=$$?; \
	  grep -E " - (error|warning) " dist/bsc-fidelity.log; \
	  if [ $$ec -ne 0 ] || grep -qE " - (error|warning) " dist/bsc-fidelity.log; then cat dist/bsc-fidelity.log; echo "fidelity-build FAILED"; exit 1; fi
	@bash tools/zip_check.sh $(FIDELITY_ZIP)
	@echo "built $(FIDELITY_ZIP)"

# Sideloads dist/fidelity.zip (replacing the dev channel), captures the FIDELITY
# console lines and tries a device screenshot into docs/fidelity/. Needs ROKU_HOST
# and ROKU_PASSWORD (env or .env). Re-deploy the channel with `make deploy` after.
fidelity-device: fidelity-build
	@ROKU_HOST="$(ROKU_HOST)" ROKU_PASSWORD="$(ROKU_PASSWORD)" bash tools/fidelity/run_device.sh docs/fidelity

# Simulator capture: ?scene=FidelityScene in the preview -> docs/fidelity/simulator.png
# and docs/fidelity/simulator-console.txt, then PIL measurements. Not part of checkall.
fidelity-sim: node_modules
	bunx playwright test --config playwright.fidelity.config.ts
	uv run tools/fidelity/measure.py docs/fidelity/simulator.png > docs/fidelity/simulator-measure.md

clean:
	rm -rf dist
