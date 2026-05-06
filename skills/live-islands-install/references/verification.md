# Verification

Run the static verifier first:

```bash
mix live_islands.verify_install
```

Then run the full frontend verifier. It runs the Vite client build, the SSR bundle build, and checks that Vite emitted JavaScript, CSS, and lazy island chunks:

```bash
mix live_islands.verify_install --full
```

If node modules are not installed yet, let the verifier install them first:

```bash
mix live_islands.verify_install --full --install
```

Then run the remaining project checks:

```bash
mix compile
mix test
```

If the project intentionally disables SSR, use `mix live_islands.verify_install --full --skip-ssr` and say that explicitly in the final report.

For a browser smoke test, render one React island and one Vue island in a page or LiveView:

```heex
<.react name="Simple" />
<.vue v-component="status" message="Vue island ready" />
```

Use Playwright or the in-app browser to confirm both islands mount and respond to a simple interaction.
