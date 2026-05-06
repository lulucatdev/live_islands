# Verification

Run the static verifier first:

```bash
mix live_islands.verify_install
```

Then run the project build checks:

```bash
npm install --prefix assets
npm run build --prefix assets
npm run build-server --prefix assets
mix compile
mix test
```

If the project intentionally disables SSR, `npm run build-server --prefix assets` may be replaced by the project's chosen SSR-disabled check. Say that explicitly in the final report.

For a browser smoke test, render one React island and one Vue island in a page or LiveView:

```heex
<.react name="Simple" />
<.vue v-component="status" message="Vue island ready" />
```

Use Playwright or the in-app browser to confirm both islands mount and respond to a simple interaction.
