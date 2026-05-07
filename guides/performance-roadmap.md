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

- API: keep the existing `prefetch={:idle | :visible | :hover | :tap}` surface
  and add application-provided `preloadUrls(name)` where Vite manifests can map
  components to concrete modulepreload URLs
- Runtime: bounded concurrency, queue/start/load/error events, and adaptive
  defaults informed by release benchmark history
- Tests: queue ordering, failure recovery, page-scope isolation, and route-flow
  e2e checks
- Benchmarks: prefetch event counts, premature heavy-library loads, route-flow
  bytes, and modulepreload impact

## v0.8 Server-Only Zero-JS Proofs

Borrowed from Fresh and Marko.

- API: no new template syntax; the verifier proves existing server-only islands
  do not attach client hooks or framework chunks
- Runtime: no extra work beyond deferred/prefetch event visibility
- Tests: static render assertions for `client="none"`, `prefetch="none"`, no
  `phx-hook`, and no hydration events
- Benchmarks: page manifest checks, heavy-library absence before user intent,
  React-only/Vue-only framework isolation, and release-to-release app entry
  budgets
