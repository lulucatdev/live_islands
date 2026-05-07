# Performance Roadmap

LiveIslands tracks framework ideas as measurable capabilities instead of design
notes. Each stage must ship with an API, tests, benchmark coverage, and release
artifact history.

## v0.6 Deferred Server Islands

Borrowed from Astro server islands.

- API: `<.react_server defer={true}>` and `<.vue_server defer={true}>`
- Runtime: signed HTML fetches through `LiveIslands.Deferred`
- Tests: unit coverage for signed payloads and browser e2e coverage for hookless
  deferred HTML
- Benchmarks: fallback in shell HTML, final HTML absent from shell HTML, deferred
  fetch bytes, deferred load timing, and server-only hook absence

## v0.7 Intent-Aware Prefetch

Borrowed from Qwik prefetch scheduling.

- API: `prefetch={:intent}` plus application-provided `preloadUrls(name)`
  where Vite manifests can map components to concrete modulepreload URLs
- Runtime: bounded concurrency, priority/reprioritization, queue/start/
  modulepreload/load/skip/error events, and save-data/slow-network protection
- Tests: static render coverage for `:intent` and browser e2e proof that the
  target component waits for pointer intent before loading
- Benchmarks: prefetch event counts, premature target-load checks, route-flow
  bytes, intent-trigger bytes, and modulepreload evidence

## v0.8 Server-Only Zero-JS Proofs

Borrowed from Fresh and Marko.

- API: no new template syntax; the verifier proves existing server-only islands
  do not attach client hooks or framework chunks
- Runtime: no extra work beyond deferred/prefetch event visibility
- Tests: static render assertions for `client="none"`, `prefetch="none"`, no
  `phx-hook`, no hydration events, no prefetch events, and no forbidden
  React/Vue client chunk loads
- Benchmarks: a dedicated `/server-only` production route, server-only byte
  totals, hook and hydration counts, forbidden chunk counts, sample stability
  rows, budgets, and release-to-release comparison metrics

## v0.9 Route-Level Shell Optimization

Borrowed from Astro layouts and Fresh islands.

- API: root layouts can pass a route-controlled asset list to
  `LiveIslands.Reload.vite_assets`, including CSS-only shells for static SSR
  pages
- Runtime: `vite_assets` skips Vite dev client and React refresh when the asset
  list contains no JavaScript entry
- Tests: `/server-only` browser e2e proves no module scripts, no LiveSocket, no
  prefetch/deferred runtime globals, no script responses, and no forbidden
  framework chunks
- Benchmarks: schema `version: 7` records shell evidence and enforces zero
  JavaScript bytes/script responses for `/server-only`
