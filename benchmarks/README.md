# Benchmarks

The benchmark suite measures the production example app, not the Vite dev server.

It builds the example assets, starts the Phoenix app in `MIX_ENV=prod`, opens the
benchmark routes in Chromium, and records:

- multiple samples per page with min/median/max/mean stability stats
- initial route bytes
- unique URL bytes and duplicate request overhead
- JavaScript and CSS bytes by page
- Vite manifest dynamic island chunks
- SSR content present in the initial HTML
- server-only island hook absence
- page-scoped island manifests after route navigation
- route-to-route LiveView navigation from `/capabilities` to `/benchmarks`
- deferred KaTeX and PDF.js bytes loaded after user intent
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

Budgets live in `benchmarks/budgets.json`. They intentionally track both total
network bytes and unique URL bytes so regressions can catch duplicate entrypoint
loads as well as real bundle growth.

The GitHub Actions benchmark workflow runs on `v*` tags and can also be started
manually. It uploads the JSON and Markdown result files as workflow artifacts.
