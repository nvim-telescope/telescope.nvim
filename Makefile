DEPDIR ?= .deps
PLENTEST := $(DEPDIR)/plentest.nvim
DOCGEN := $(DEPDIR)/docgen.nvim
DOCGEN_TAG := v1.1.0

.PHONY: plentest
plentest: $(PLENTEST)

$(PLENTEST):
	git clone --filter=blob:none https://github.com/nvim-treesitter/plentest.nvim $(PLENTEST)

.PHONY: test lint docgen
test: $(PLENTEST)
	PLENTEST=$(PLENTEST) nvim --headless --clean -u scripts/minimal_init.lua \
		-c "lua require('plentest').test_directory('tests/automated', { minimal_init = './scripts/minimal_init.lua' })"

lint:
	luacheck lua/telescope

.PHONY: docgen
docgen: $(DOCGEN)

$(DOCGEN):
	git clone --filter=blob:none --branch $(DOCGEN_TAG) https://github.com/jamestrew/docgen.nvim $(DOCGEN)

.PHONY: docs
docs: $(DOCGEN)
	nvim -l scripts/gendocs.lua

.PHONY: clean
clean:
	rm -rf $(DEPDIR)
