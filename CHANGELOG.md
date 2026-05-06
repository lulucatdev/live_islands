# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## v0.2.0

Astro-style loading and runtime ergonomics for page-aware islands.

- Added page-aware island prefetching with DOM manifests, lazy chunk preload support, and `getIslandManifest` / `setupIslandPrefetch` helpers.
- Added built-in `:interaction` hydration and prefetch strategies, plus `defineClientStrategy` and `definePrefetchStrategy` for application-defined scheduling.
- Added first-class server-only React and Vue islands with `<.react_server>` and `<.vue_server>`.
- Expanded installer guidance, integration checklists, verifier coverage, example coverage, and E2E tests for Vite, Tailwind, React, Vue, SSR, and lazy chunks.

## v0.1.0

Initial independent LiveIslands release with React and Vue component islands for Phoenix LiveView.

- Unified React and Vue adapters under one Elixir package and JavaScript package.
- Added Vite, Tailwind, SSR, lazy hydration, and install verification workflows.
- Added attribution for `mrdotb/live_react` and `Valian/live_vue`.
