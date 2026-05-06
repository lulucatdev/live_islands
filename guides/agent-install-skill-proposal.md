# Agent Install Skill Proposal

This proposal records the experiment of moving LiveIslands installation away from a universal Mix installer and toward a pi/Codex install skill backed by a verifier suite.

## Recommendation

Use an agent install skill as the primary installation path.

Keep `mix live_islands.install` as a copy-only scaffold for now. It should copy missing starter files under `assets/` and preserve existing files. It should not rewrite `mix.exs`, JavaScript, layouts, config, Tailwind, daisyUI, or user CSS.

Keep `mix live_islands.verify_install` as the contract. The verifier should tell the agent and user whether the required LiveIslands integration points are present, then real builds and a small browser smoke test should prove the install works.

This gives us a cleaner split:

- LiveIslands owns the required integration contract.
- The agent owns project-specific edits.
- The host Phoenix app keeps its UI and asset choices unless the user asks to change them.

## Why Not A Universal Installer

Phoenix applications vary too much for a regex-heavy installer to be trustworthy:

- Phoenix 1.8 apps can start with Tailwind 4, daisyUI, colocated hooks, and Mix-managed assets.
- Existing apps may already use Vite, custom Tailwind plugins, daisyUI themes, shadcn-style components, or a private design system.
- LiveIslands requires React/Vue/Vite/SSR wiring, but it does not require removing daisyUI.

An install skill can inspect the actual project first and make narrower edits. A verifier can then judge the result without guessing how the project got there.

## Install Skill Shape

Place the skill in `skills/live-islands-install/`.

`SKILL.md` should stay short:

- Trigger when the user asks to add or verify LiveIslands, React islands, Vue islands, or SSR islands in a Phoenix project.
- Inspect before editing.
- Preserve the host app's UI stack by default.
- Add only the required LiveIslands integration points.
- Use the scaffold task only for missing starter files.
- Run verifier/build/browser checks and report results.

`references/integration-checklist.md` should carry the detailed contract:

- Add `{:live_islands, ...}` to `mix.exs`.
- Import `LiveIslands` from `html_helpers/0` in `lib/*_web.ex`.
- Ensure `assets/package.json` has `live_islands`, Vite, React, React DOM, Vue, Phoenix JS packages, and Vite plugins.
- Ensure `assets/vite.config.*` has React, Vue, and `live_islands/vite-plugin`.
- Preserve colocated hooks by aliasing `phoenix-colocated` to the Mix build output when the app imports them.
- Combine `getIslandHooks({react, vue})` with existing `LiveSocket` hooks in `assets/js/app.js`.
- Add `assets/react-components/index.js`, `assets/vue-components/index.js`, and `assets/js/server.js`.
- Wrap root layout Vite assets with `LiveIslands.Reload.vite_assets`.
- Configure SSR with `LiveIslands.SSR.ViteJS` in dev and `LiveIslands.SSR.NodeJS` in prod, or explicitly set `ssr: false`.
- Add the `NodeJS.Supervisor` only when production SSR is enabled.

`references/verification.md` should be the install completion rubric:

- Run the static verifier.
- Run `mix live_islands.verify_install --full` to execute the Vite client build, SSR bundle build, and artifact checks.
- Run Elixir compile/tests.
- Render one React island and one Vue island in a real Phoenix page.
- Confirm both islands mount in a browser and can handle a small interaction.

Optional `scripts/` can be added after the workflow stabilizes:

- `scripts/inspect-project.sh`: summarize Phoenix version, LiveView version, Vite presence, package manager, CSS entrypoint, colocated hooks import, and daisyUI presence.
- `scripts/verify-static.sh`: run `mix live_islands.verify_install` and emit a compact failure summary.
- `scripts/smoke-new-phoenix.sh`: generate a fresh Phoenix app, let an agent install LiveIslands, then run the verifier/build/browser smoke checks.

## daisyUI Policy

The install skill must not remove daisyUI by default.

If `assets/css/app.css` already includes daisyUI plugins or themes, the agent should preserve them and only add Tailwind source coverage for island component roots:

```css
@source "../react-components";
@source "../vue-components";
```

If moving a Phoenix 1.8 app from Mix-managed assets to Vite, the agent should verify that the existing CSS still builds through Vite/Tailwind. daisyUI vendor files or CSS plugin blocks are not an installation failure.

Only remove daisyUI when the user explicitly asks for a non-daisyUI default or when the existing daisyUI setup is demonstrably broken and the user approves the tradeoff.

## Verifier Suite

The verifier should check static project shape first:

- `mix.exs` contains `:live_islands`.
- `assets/package.json` contains LiveIslands, Vite, Tailwind, React, React DOM, Vue, and required Vite plugins.
- `assets/vite.config.*` imports/configures Tailwind, React, Vue, and `live_islands/vite-plugin`.
- `assets/css/app.css` imports Tailwind and scans React/Vue component roots.
- `assets/js/app.js` imports `getIslandHooks`, React components, and Vue components, then passes the combined hooks to `LiveSocket`.
- React and Vue component roots exist.
- React and Vue registries use async imports so Vite can emit lazy island chunks.
- `assets/js/server.js` can dispatch SSR for both React and Vue.
- `lib/*_web.ex` imports `LiveIslands`.
- The root layout loads Vite module assets and uses `LiveIslands.Reload.vite_assets` for dev.
- `config/*.exs` contains explicit LiveIslands SSR config or `ssr: false`.

The verifier should not check for daisyUI removal.

After static checks, the install skill should run:

```bash
rtk mix live_islands.verify_install
rtk mix live_islands.verify_install --full
rtk mix compile
rtk mix test
```

If SSR is intentionally disabled, run `rtk mix live_islands.verify_install --full --skip-ssr` and report that choice.

Browser smoke should add or reuse a page with both frameworks:

```heex
<.react name="Simple" />
<.vue v-component="status" message="Vue island ready" />
```

The smoke test should prove:

- The page renders without LiveView or Vite console errors.
- The React island mounts and shows expected text or state.
- The Vue island mounts and shows expected text or state.
- At least one island can send or receive a LiveView event when the app exposes that behavior.

## Installer Decision

Do not delete the Mix task immediately.

Recommended lifecycle:

1. Now: keep `mix live_islands.install` as copy-only scaffold and document it as optional.
2. Next: mark the task as scaffold-only/experimental in docs and task output.
3. Later: if the install skill and verifier become the stable path, either keep the scaffold task indefinitely as a convenience or deprecate it before removal.

The task should never claim to complete installation by itself. Completion belongs to the verifier/build/browser suite.

## Prototype Acceptance

This experiment is successful when a fresh Phoenix app can be installed by an agent using only the skill and templates, while preserving daisyUI if present, and the following pass:

```bash
rtk mix live_islands.verify_install
rtk npm run build --prefix assets
rtk npm run build-server --prefix assets
rtk mix compile
rtk mix test
```

A stronger acceptance test is an automated end-to-end smoke that generates a fresh Phoenix project, installs LiveIslands through the skill workflow, renders both React and Vue islands, and confirms both are mounted in a browser.
