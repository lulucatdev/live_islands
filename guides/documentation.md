# Documentation

LiveIslands publishes one documentation surface on HexDocs. The goal is that a
developer can move from install, to runtime concepts, to production deployment,
to benchmark evidence without leaving the package docs.

## Local Commands

The repository `Makefile` is the preferred entrypoint:

```bash
make docs
make docs-open
make docs-check
make hex-build
```

`make docs-check` runs ExDoc with `--warnings-as-errors`; use it before every
release. `make hex-build` depends on `docs-check` and then builds the Hex
package tarball.

You can still call Mix directly:

```bash
mix docs --formatter html
mix docs --formatter html --warnings-as-errors
mix hex.build
```

## HexDocs Structure

The ExDoc sidebar is grouped around the way people adopt the project:

- **Start**: overview and installation
- **Runtime**: lazy islands, SSR, and deployment
- **Operations**: development, benchmarks, and documentation maintenance
- **Agent Installation**: the install skill and verifier checklists
- **Reference**: performance roadmap, changelog, notice, and license

The API reference is grouped separately:

- `LiveIslands`, `LiveIslands.React`, and `LiveIslands.Vue` for component usage
- `LiveIslands.Reload` and `LiveIslands.Deferred` for runtime integration
- `LiveIslands.SSR.*` for server rendering adapters
- `LiveIslands.Encoder` and `LiveIslands.Patch` for data encoding and patches
- `LiveIslands.Test` for test helpers
- Mix tasks for install and verification workflows

## Release Checklist

Before publishing a release that will appear on HexDocs:

```bash
make check
make benchmark-smoke
make hex-build
```

For a release tag, also run the full production benchmark or let GitHub Actions
run it on the pushed `v*` tag:

```bash
make benchmark
```

The benchmark workflow uploads `live-islands-benchmark.json` and
`live-islands-benchmark.md` to the GitHub Release and appends the benchmark
summary to the release body. HexDocs should link to the same concepts, while the
release page carries the exact environment and measured artifact for that
version.

## Package Contents

The Hex package includes:

- Elixir source under `lib/`
- JavaScript runtime and templates under `assets/`
- install skill and verifier references under `skills/`
- guides and benchmark documentation
- `Makefile`, `README.md`, `CHANGELOG.md`, `NOTICE.md`, `LICENSE.md`, and
  `logo.svg`

Machine-specific benchmark result files remain ignored and are published as
release assets instead of package source.
