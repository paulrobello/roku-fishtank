ZIP := dist/fishtank-test.zip

.PHONY: build deploy checkall clean art

build: $(ZIP)

$(ZIP): manifest source/main.brs components/FishtankTest.xml components/FishtankTest.brs images
	mkdir -p dist
	rm -f $(ZIP)
	zip -r $(ZIP) manifest source components images -x "*.DS_Store" > /dev/null

# ROKU_HOST=<ip> ROKU_PASSWORD=<dev password> make deploy
deploy: build
	curl -sS -f --digest --user rokudev:$(ROKU_PASSWORD) -F "mysubmit=1" -F "archive=@$(ZIP)" "http://$(ROKU_HOST)/plugin_install"

checkall: build
	unzip -l $(ZIP) | grep -E "manifest|main\.brs|FishtankTest\.xml|FishtankTest\.brs|fish_|pebbles|icon_|splash_" | sort

art:
	python3 tools/make_art.py

clean:
	rm -rf dist
