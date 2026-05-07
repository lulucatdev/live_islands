# Development

The easiest way to get started with development is to clone LiveIslands, install
dependencies, and run the example app.

```bash
git clone https://github.com/lulucatdev/live_islands.git
cd live_islands
make setup
make demo
```

The demo defaults to:

- Phoenix: `http://127.0.0.1:4012`
- Vite: `http://localhost:5174`

Override ports when needed:

```bash
make demo PORT=4020 VITE_PORT=5180
```

## Common Commands

```bash
make help
make compile
make test
make e2e
make benchmark-smoke
make docs-check
```

`make check` runs the standard local verification suite: library compile,
example compile, Elixir tests, Credo, browser e2e tests, and ExDoc warnings as
errors.

The examples include:

- `/todo` for the full LiveView, React, Vue, SSR, deferred, lazy, and benchmark
  demo
- `/capabilities` for capability coverage
- `/benchmarks` for the heavy KaTeX/PDF benchmark surface
- `/server-only` for zero-JS server-only islands
- `/profile/react-only`, `/profile/vue-only`, and `/profile/mixed` for
  route-level asset profiles
