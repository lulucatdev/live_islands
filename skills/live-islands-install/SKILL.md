---
name: live-islands-install
description: Install LiveIslands into a Phoenix project with React and Vue islands, using the project's existing asset choices when possible. Use when a user asks to add LiveIslands, live_islands, React islands, Vue islands, or to verify a LiveIslands installation.
---

# LiveIslands Install

Install LiveIslands as an integration task, not as a blind patch.

Start by reading the target Phoenix project:

1. Inspect `mix.exs`, `assets/package.json`, `assets/vite.config.*`, `assets/js/app.js`, `assets/css/app.css`, `lib/*_web.ex`, root layout, and `config/*.exs`.
2. Decide whether the project already uses Vite. Prefer adapting existing Vite config over replacing it.
3. Preserve existing UI choices. Do not remove daisyUI, custom Tailwind plugins, themes, CSS, or vendor files unless the user explicitly asks.
4. Wire only the LiveIslands-required integration points from `references/integration-checklist.md`.
5. Run the static verifier, full frontend verifier, and remaining build/test commands from `references/verification.md`.

Use `mix live_islands.install` only as an optional scaffold copier for missing files under `assets/`. It intentionally does not patch project files.

When reporting completion, include the files changed, whether daisyUI was preserved or intentionally removed, and the verifier/build results.
