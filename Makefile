SHELL := /bin/bash

MIX ?= mix
NPM ?= npm
NPX ?= npx

PORT ?= 4012
VITE_PORT ?= 5174
VITE_HOST ?= http://localhost:$(VITE_PORT)

ROOT := $(CURDIR)
EXAMPLE := $(ROOT)/live_islands_examples
EXAMPLE_ASSETS := $(EXAMPLE)/assets

.DEFAULT_GOAL := help
.NOTPARALLEL:

.PHONY: help deps example-deps setup compile example-compile test credo format format-check lint check e2e docs docs-open docs-check hex-build demo benchmark benchmark-smoke clean

help: ## Show available commands.
	@awk 'BEGIN {FS = ":.*##"; printf "\nLiveIslands commands\n\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install root Mix and npm dependencies.
	$(MIX) deps.get
	$(NPM) install

example-deps: ## Install example Mix and asset dependencies.
	cd $(EXAMPLE) && $(MIX) deps.get
	cd $(EXAMPLE_ASSETS) && $(NPM) install

setup: deps example-deps ## Install all project dependencies.

compile: ## Compile the library with warnings as errors.
	$(MIX) compile --warnings-as-errors

example-compile: ## Compile the example app with warnings as errors.
	cd $(EXAMPLE) && $(MIX) compile --warnings-as-errors

test: ## Run Elixir tests.
	$(MIX) test

credo: ## Run Credo.
	$(MIX) credo

format: ## Format Elixir and JavaScript/Markdown sources.
	$(MIX) format
	$(NPX) prettier --write .

format-check: ## Check Elixir and JavaScript/Markdown formatting.
	$(MIX) format --check-formatted
	$(NPX) prettier --check .

lint: credo format-check ## Run style and static checks.

check: compile example-compile test credo format-check e2e docs-check ## Run the standard local verification suite.

e2e: ## Run Playwright browser e2e tests against the example app.
	$(NPM) run e2e:test

docs: ## Build local HexDocs HTML into doc/.
	$(MIX) docs --formatter html

docs-open: ## Build and open local HexDocs.
	$(MIX) docs --formatter html --open

docs-check: ## Build docs and fail on ExDoc warnings.
	$(MIX) docs --formatter html --warnings-as-errors

hex-build: docs-check ## Build the Hex package tarball after docs validation.
	$(MIX) hex.build

demo: ## Run the LiveIslands example app with Vite on PORT/VITE_PORT.
	cd $(EXAMPLE) && PORT=$(PORT) VITE_PORT=$(VITE_PORT) VITE_HOST=$(VITE_HOST) $(MIX) phx.server

benchmark: ## Run the full production benchmark suite.
	$(NPM) run benchmarks

benchmark-smoke: ## Run a one-sample production benchmark smoke test.
	$(NPM) run benchmarks:smoke

clean: ## Remove generated build, docs, benchmark, and package artifacts.
	rm -rf _build doc benchmarks/results/*.json benchmarks/results/*.md live_islands-*.tar
