# Benchmarks

The benchmark suite measures the production example app, not the Vite dev server.

It builds the example assets, starts the Phoenix app in `MIX_ENV=prod`, opens the
benchmark routes in Chromium, and records:

- multiple samples per page with min/median/max/mean stability stats
- initial route bytes
- unique URL bytes and duplicate request overhead
- JavaScript and CSS bytes by page
- app entry bytes and Vite artifact gzip bytes
- FCP, LCP, hydrated island count, last-hydrated time, deferred island time, and prefetch event counts
- intent prefetch bytes, timing, modulepreload links, and proof that target chunks wait for explicit intent
- Vite manifest dynamic island chunks
- SSR content present in the initial HTML
- server-only and deferred island hook absence
- deferred server island fallback visibility, final HTML fetch bytes, and final HTML absence from the shell response
- page-scoped island manifests after route navigation
- route-to-route LiveView navigation from `/capabilities` to `/benchmarks`
- an intent prefetch flow on `/capabilities`
- deferred KaTeX and PDF.js bytes loaded after user intent
- the OS, runtime, browser, CI, and package environment used for the run
- browser console/page errors that would make the benchmark misleading

Run the full suite:

```bash
npm run benchmarks
```

Useful options:

```bash
node benchmarks/run.mjs --skip-build
node benchmarks/run.mjs --samples=1
node benchmarks/run.mjs --skip-flow
node benchmarks/run.mjs --out=benchmarks/results/v0.4.0.json
node benchmarks/run.mjs --compare=benchmarks/results/v0.3.0.json
node benchmarks/run.mjs --budget=benchmarks/budgets.json
```

Use `npm run benchmarks:smoke` for a one-sample production smoke test while
developing the benchmark runner itself.

The runner writes `benchmarks/results/latest.json` and a matching Markdown
summary. Result files are ignored by git because byte counts vary by machine,
Node version, and Phoenix production settings.

Budgets live in `benchmarks/budgets.json`. They intentionally track total
network bytes, unique URL bytes, app entry bytes, runtime timings, deferred
island bytes, intent prefetch bytes, and relative release-to-release
regressions. This catches duplicate entrypoint loads, real bundle growth, slower
hydration, slower deferred SSR fetches, premature intent loads, and accidental
loss of lazy framework loading.

The GitHub Actions benchmark workflow runs on `v*` tags and can also be started
manually. It uploads the JSON and Markdown result files as workflow artifacts.
For release tags, it also publishes stable assets on the GitHub Release:

- `live-islands-benchmark.json`
- `live-islands-benchmark.md`

When the previous release has `live-islands-benchmark.json`, the workflow
downloads it and runs the new benchmark with `--compare`, so every release can
show whether initial bytes, heavy interaction bytes, route-flow bytes, and
intent prefetch bytes moved up or down. The workflow also appends the generated benchmark Markdown summary
to the GitHub Release body under a stable marker, so the release page itself
shows the current benchmark evidence.

## Current Test Environment

The canonical release benchmark environment is the GitHub Actions
`Benchmarks` workflow:

- runner: GitHub-hosted `ubuntu-latest`
- Erlang/OTP: `27.2.0`
- Elixir: `1.18.1`
- Node.js: `22`
- browser: Playwright Chromium installed by `npx playwright install --with-deps chromium`
- Phoenix mode: `MIX_ENV=prod`, `PHX_SERVER=true`, `PHX_HOST=127.0.0.1`
- benchmark server port: `4317`
- samples: `3` per page by default

The local environment used while developing this benchmark stage was:

- OS: macOS `26.4.1` (`arm64`)
- Erlang/OTP: `27`
- Elixir: `1.18.2`
- Node.js: `25.9.0`
- npm: `11.12.1`
- Playwright: `1.59.1`

Each generated benchmark JSON also includes an `environment` object with the
actual system, runtime, browser, package, command, and GitHub runner metadata for
that specific run.
