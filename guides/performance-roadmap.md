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

## v0.10 Island-Aware Asset Profiles

Borrowed from Astro page layouts and Remix route contracts.

- API: `LiveIslands.asset_profile/2` and `LiveIslands.put_asset_profile/3`
  expose named profiles such as `:server_only`, `:css_only`, `:zero_js`,
  `:islands`, `:liveview`, and explicit asset lists
- Runtime: root layouts consume `:live_islands_assets`, while
  `LiveIslands.Reload.vite_assets` expands profiles before deciding whether to
  emit CSS, JavaScript, the Vite dev client, or React refresh
- Tests: unit coverage for profile expansion and browser e2e coverage for
  React-only, Vue-only, and mixed profile routes
- Benchmarks: schema `version: 8` records profile page total bytes, JavaScript
  bytes, module scripts, LiveSocket presence, frameworks in the page manifest,
  hydration counts, budgets, and release-to-release comparison metrics

## v0.11 Complex Demo App

Borrowed from Linear-style command surfaces, Todoist-style task flow, and
Astro's product-page insistence on measuring what users actually load.

- API: no new public API; the stage proves the existing React/Vue island
  surface can compose a full product workflow
- Runtime: `/todo` uses React and Vue islands together with server-only SSR,
  deferred server islands, `client={:load | :visible | :interaction}`,
  `prefetch={:load | :idle | :intent}`, event replies, LiveView event pushes,
  and page-scoped manifests
- Tests: browser e2e covers task creation, event-reply planning, Vue mode
  switching, command-center interaction hydration, focus timer hydration,
  server-only hook absence, and manifest assertions
- Benchmarks: schema `version: 9` records Todo initial total bytes, initial
  JavaScript bytes, hydrated island counts, deferred SSR fetch bytes, workflow
  interaction bytes, interaction duration, SSR proof rows, budgets, and
  release-to-release comparison metrics
