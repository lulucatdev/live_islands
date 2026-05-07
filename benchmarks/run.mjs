#!/usr/bin/env node
import { chromium } from "@playwright/test";
import { execFileSync, spawn } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { arch, cpus, platform, release, totalmem, type } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { gzipSync } from "node:zlib";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const exampleRoot = join(root, "live_islands_examples");
const staticAssets = join(exampleRoot, "priv/static/assets");
const resultsDir = join(root, "benchmarks/results");
const defaultBudgetPath = join(root, "benchmarks/budgets.json");

const args = new Map(
  process.argv.slice(2).map((arg) => {
    const [key, value = "true"] = arg.split("=");
    return [key.replace(/^--/, ""), value];
  }),
);

const port = Number(args.get("port") || 4317);
const baseURL = `http://127.0.0.1:${port}`;
const skipBuild = args.get("skip-build") === "true";
const keepServer = args.get("keep-server") === "true";
const sampleCount = positiveIntegerArg("samples", 3);
const skipFlow = args.get("skip-flow") === "true";
const comparePath = args.get("compare");
const budgetPath = args.get("budget") || defaultBudgetPath;
const outPath = resolve(args.get("out") || join(resultsDir, "latest.json"));
const markdownPath = outPath.replace(/\.json$/, ".md");

function positiveIntegerArg(name, fallback) {
  const raw = args.get(name);
  if (raw === undefined) return fallback;

  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;

  return Math.floor(parsed);
}

function run(command, commandArgs, options = {}) {
  console.log(`$ ${[command, ...commandArgs].join(" ")}`);
  execFileSync(command, commandArgs, {
    cwd: options.cwd || root,
    env: { ...process.env, ...(options.env || {}) },
    stdio: "inherit",
  });
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function commandOutput(command, commandArgs, options = {}) {
  try {
    return execFileSync(command, commandArgs, {
      cwd: options.cwd || root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch (_error) {
    return null;
  }
}

function dependencyVersion(packageJson, name) {
  return (
    packageJson.dependencies?.[name] ||
    packageJson.devDependencies?.[name] ||
    packageJson.peerDependencies?.[name] ||
    null
  );
}

function bytes(path) {
  if (!existsSync(path)) return { bytes: 0, gzipBytes: 0 };
  const content = readFileSync(path);
  return {
    bytes: content.length,
    gzipBytes: gzipSync(content).length,
  };
}

function fileMetrics(file) {
  const path = join(staticAssets, file);
  return { file, ...bytes(path) };
}

function buildArtifacts() {
  const manifestPath = join(staticAssets, ".vite/manifest.json");
  const manifest = readJson(manifestPath);
  const entries = Object.entries(manifest);
  const dynamicEntries = entries.filter(
    ([_key, value]) => value.isDynamicEntry,
  );
  const appEntry =
    manifest["js/app.js"] ||
    entries.find(([_key, value]) => value.isEntry)?.[1];
  const benchmarkEntries = entries.filter(([key]) =>
    key.toLowerCase().includes("benchmark"),
  );
  const heavyEntries = entries.filter(([key, value]) => {
    const haystack = `${key} ${value.file || ""}`.toLowerCase();
    return haystack.includes("katex") || haystack.includes("pdf");
  });

  const entryFiles = new Map();
  for (const [_key, value] of entries) {
    if (value.file) entryFiles.set(value.file, fileMetrics(value.file));
    for (const css of value.css || []) entryFiles.set(css, fileMetrics(css));
    for (const asset of value.assets || [])
      entryFiles.set(asset, fileMetrics(asset));
  }

  return {
    manifestPath: relative(root, manifestPath),
    entryCount: entries.length,
    dynamicEntryCount: dynamicEntries.length,
    app: appEntry?.file ? fileMetrics(appEntry.file) : null,
    benchmark: benchmarkEntries.map(([key, value]) => ({
      key,
      file: value.file,
      fileMetrics: value.file ? fileMetrics(value.file) : null,
      css: (value.css || []).map(fileMetrics),
      imports: value.imports || [],
      dynamicImports: value.dynamicImports || [],
    })),
    heavyLibraries: heavyEntries.map(([key, value]) => ({
      key,
      file: value.file,
      fileMetrics: value.file ? fileMetrics(value.file) : null,
    })),
    totals: Array.from(entryFiles.values()).reduce(
      (acc, metric) => ({
        bytes: acc.bytes + metric.bytes,
        gzipBytes: acc.gzipBytes + metric.gzipBytes,
      }),
      { bytes: 0, gzipBytes: 0 },
    ),
  };
}

async function waitForServer() {
  const deadline = Date.now() + 120_000;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${baseURL}/benchmarks`);
      if (response.ok) return;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }

    await new Promise((resolveWait) => setTimeout(resolveWait, 500));
  }

  throw lastError || new Error("Timed out waiting for benchmark server");
}

function startServer() {
  const secret =
    "benchmark-secret-key-base-that-is-long-enough-for-phoenix-live-islands";

  const child = spawn("mix", ["phx.server"], {
    cwd: exampleRoot,
    env: {
      ...process.env,
      MIX_ENV: "prod",
      PHX_SERVER: "true",
      PHX_HOST: "127.0.0.1",
      PORT: String(port),
      SECRET_KEY_BASE: secret,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  child.stdout.on("data", (chunk) =>
    process.stdout.write(`[bench-server] ${chunk}`),
  );
  child.stderr.on("data", (chunk) =>
    process.stderr.write(`[bench-server] ${chunk}`),
  );

  return child;
}

function summarizeResponses(responses) {
  const groups = {};
  const uniqueUrls = new Map();

  for (const response of responses) {
    const key = response.resourceType || "other";
    groups[key] ||= { count: 0, bytes: 0 };
    groups[key].count += 1;
    groups[key].bytes += response.bytes;

    const current = uniqueUrls.get(response.url);
    if (!current || response.bytes > current.bytes) {
      uniqueUrls.set(response.url, response);
    }
  }

  const uniqueResponses = Array.from(uniqueUrls.values());
  const scriptExtensions = new Set([".js", ".mjs"]);
  const isScript = (response) => {
    const pathname = new URL(response.url).pathname;
    return Array.from(scriptExtensions).some((extension) =>
      pathname.endsWith(extension),
    );
  };
  const isStylesheet = (response) =>
    new URL(response.url).pathname.endsWith(".css");
  const totalBytes = responses.reduce(
    (sum, response) => sum + response.bytes,
    0,
  );
  const uniqueBytes = uniqueResponses.reduce(
    (sum, response) => sum + response.bytes,
    0,
  );

  return {
    count: responses.length,
    totalBytes,
    uniqueBytes,
    duplicateBytes: totalBytes - uniqueBytes,
    failedResponses: responses
      .filter((response) => response.status >= 400)
      .map((response) => ({
        url: response.url.replace(baseURL, ""),
        status: response.status,
        resourceType: response.resourceType,
        bytes: response.bytes,
      })),
    groups,
    jsBytes: responses
      .filter(isScript)
      .reduce((sum, response) => sum + response.bytes, 0),
    uniqueJsBytes: uniqueResponses
      .filter(isScript)
      .reduce((sum, response) => sum + response.bytes, 0),
    cssBytes: responses
      .filter(isStylesheet)
      .reduce((sum, response) => sum + response.bytes, 0),
    uniqueCssBytes: uniqueResponses
      .filter(isStylesheet)
      .reduce((sum, response) => sum + response.bytes, 0),
    urls: responses.map((response) => ({
      url: response.url.replace(baseURL, ""),
      resourceType: response.resourceType,
      bytes: response.bytes,
    })),
    topUrls: [...responses]
      .sort((left, right) => right.bytes - left.bytes)
      .slice(0, 10)
      .map((response) => ({
        url: response.url.replace(baseURL, ""),
        resourceType: response.resourceType,
        bytes: response.bytes,
      })),
  };
}

function attachDiagnostics(page) {
  const responsePromises = [];
  const browserErrors = [];

  page.on("console", (message) => {
    if (message.type() === "error") {
      browserErrors.push({
        type: "console",
        text: message.text(),
      });
    }
  });
  page.on("pageerror", (error) => {
    browserErrors.push({
      type: "pageerror",
      text: error.message,
    });
  });

  page.on("response", (response) => {
    if (!response.url().startsWith(baseURL)) return;

    responsePromises.push(
      response
        .finished()
        .then(async () => {
          let body = Buffer.alloc(0);
          try {
            body = await response.body();
          } catch (_error) {
            body = Buffer.alloc(0);
          }

          return {
            url: response.url(),
            status: response.status(),
            resourceType: response.request().resourceType(),
            bytes: body.length,
          };
        })
        .catch(() => null),
    );
  });

  return { responsePromises, browserErrors };
}

async function installRuntimeProbe(page) {
  await page.addInitScript(() => {
    const state = {
      paints: {},
      largestContentfulPaint: null,
      mounted: [],
      hydrated: [],
      deferred: {
        started: [],
        loaded: [],
        errors: [],
      },
      prefetch: {
        queued: [],
        started: [],
        modulepreloaded: [],
        loaded: [],
        errors: [],
        skipped: [],
      },
    };

    window.__liveIslandsBenchmarkRuntime = state;

    const rememberIsland = (event, target) => {
      const el = event.detail?.el;
      target.push({
        time: Math.round(performance.now()),
        framework:
          event.detail?.framework || el?.getAttribute?.("data-framework"),
        name: event.detail?.name || el?.getAttribute?.("data-name"),
        client: el?.getAttribute?.("data-client") || null,
        prefetch: el?.getAttribute?.("data-prefetch") || null,
      });
    };

    const rememberRuntimeEvent = (event, target) => {
      const el = event.detail?.el;
      target.push({
        time: Math.round(performance.now()),
        framework:
          event.detail?.framework || el?.getAttribute?.("data-framework"),
        name: event.detail?.name || el?.getAttribute?.("data-name"),
        duration: event.detail?.duration ?? null,
        bytes: event.detail?.bytes ?? null,
        policy: event.detail?.policy ?? null,
        trigger: event.detail?.trigger ?? null,
        priority: event.detail?.priority ?? null,
        modulepreloadCount:
          event.detail?.modulepreloadCount ?? event.detail?.count ?? 0,
        modulepreloadUrls:
          event.detail?.modulepreloadUrls || event.detail?.urls || [],
        reason: event.detail?.reason ?? null,
        message: event.detail?.message ?? null,
      });
    };

    try {
      const paintObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          state.paints[entry.name] = Math.round(entry.startTime);
        }
      });
      paintObserver.observe({ type: "paint", buffered: true });
    } catch (_error) {
      // Paint timing is not available in every browser context.
    }

    try {
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const entry = entries[entries.length - 1];
        if (entry) {
          state.largestContentfulPaint = {
            startTime: Math.round(entry.startTime),
            size: entry.size || 0,
            element: entry.element?.tagName || null,
            url: entry.url || null,
          };
        }
      });
      lcpObserver.observe({ type: "largest-contentful-paint", buffered: true });
    } catch (_error) {
      // LCP is best effort for local benchmark runs.
    }

    window.addEventListener("live-islands:mounted", (event) =>
      rememberIsland(event, state.mounted),
    );
    window.addEventListener("live-islands:hydrated", (event) =>
      rememberIsland(event, state.hydrated),
    );
    window.addEventListener("live-islands:deferred:start", (event) =>
      rememberRuntimeEvent(event, state.deferred.started),
    );
    window.addEventListener("live-islands:deferred:load", (event) =>
      rememberRuntimeEvent(event, state.deferred.loaded),
    );
    window.addEventListener("live-islands:deferred:error", (event) =>
      rememberRuntimeEvent(event, state.deferred.errors),
    );
    window.addEventListener("live-islands:prefetch:queue", (event) =>
      rememberRuntimeEvent(event, state.prefetch.queued),
    );
    window.addEventListener("live-islands:prefetch:start", (event) =>
      rememberRuntimeEvent(event, state.prefetch.started),
    );
    window.addEventListener("live-islands:prefetch:modulepreload", (event) =>
      rememberRuntimeEvent(event, state.prefetch.modulepreloaded),
    );
    window.addEventListener("live-islands:prefetch:load", (event) =>
      rememberRuntimeEvent(event, state.prefetch.loaded),
    );
    window.addEventListener("live-islands:prefetch:error", (event) =>
      rememberRuntimeEvent(event, state.prefetch.errors),
    );
    window.addEventListener("live-islands:prefetch:skip", (event) =>
      rememberRuntimeEvent(event, state.prefetch.skipped),
    );
  });
}

async function runtimeMetrics(page) {
  return page.evaluate(() => {
    const state = window.__liveIslandsBenchmarkRuntime || {};
    const paintEntries = performance.getEntriesByType("paint");
    const paints = { ...(state.paints || {}) };

    for (const entry of paintEntries) {
      paints[entry.name] = Math.round(entry.startTime);
    }

    const hydrated = state.hydrated || [];
    const firstHydrated = hydrated[0]?.time ?? null;
    const lastHydrated = hydrated[hydrated.length - 1]?.time ?? null;
    const deferredLoaded = state.deferred?.loaded || [];
    const firstDeferredStarted = state.deferred?.started?.[0]?.time ?? null;
    const lastDeferredLoaded =
      deferredLoaded[deferredLoaded.length - 1]?.time ?? null;

    return {
      firstPaint: paints["first-paint"] ?? null,
      firstContentfulPaint: paints["first-contentful-paint"] ?? null,
      largestContentfulPaint: state.largestContentfulPaint?.startTime ?? null,
      largestContentfulPaintSize: state.largestContentfulPaint?.size ?? null,
      islands: {
        mountedCount: state.mounted?.length || 0,
        hydratedCount: hydrated.length,
        firstHydrated,
        lastHydrated,
        hydrationSpan:
          firstHydrated != null && lastHydrated != null
            ? lastHydrated - firstHydrated
            : null,
        hydrated,
      },
      deferred: {
        startedCount: state.deferred?.started?.length || 0,
        loadedCount: deferredLoaded.length,
        errorCount: state.deferred?.errors?.length || 0,
        firstStarted: firstDeferredStarted,
        lastLoaded: lastDeferredLoaded,
        loadSpan:
          firstDeferredStarted != null && lastDeferredLoaded != null
            ? lastDeferredLoaded - firstDeferredStarted
            : null,
        loaded: deferredLoaded,
        errors: state.deferred?.errors || [],
      },
      prefetch: {
        queuedCount: state.prefetch?.queued?.length || 0,
        startedCount: state.prefetch?.started?.length || 0,
        modulepreloadedCount: state.prefetch?.modulepreloaded?.length || 0,
        loadedCount: state.prefetch?.loaded?.length || 0,
        errorCount: state.prefetch?.errors?.length || 0,
        skippedCount: state.prefetch?.skipped?.length || 0,
        modulepreloaded: state.prefetch?.modulepreloaded || [],
        loaded: state.prefetch?.loaded || [],
        errors: state.prefetch?.errors || [],
        skipped: state.prefetch?.skipped || [],
      },
    };
  });
}

async function collectPage(browser, pathname, options = {}) {
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    serviceWorkers: "block",
  });
  const page = await context.newPage();
  await installRuntimeProbe(page);
  const { responsePromises, browserErrors } = attachDiagnostics(page);

  const navigationStarted = Date.now();
  await page.goto(`${baseURL}${pathname}`, { waitUntil: "networkidle" });
  const navigationMs = Date.now() - navigationStarted;
  const html = await fetch(`${baseURL}${pathname}`).then((response) =>
    response.text(),
  );

  const initialResponses = (await Promise.all(responsePromises)).filter(
    Boolean,
  );
  const initialCount = responsePromises.length;
  const deferredResponses = initialResponses.filter((response) =>
    new URL(response.url).pathname.includes("/live-islands/deferred"),
  );

  let interaction = null;
  if (options.heavyInteraction) {
    await page.evaluate(() =>
      document
        .querySelector("#benchmark_workbench")
        ?.scrollIntoView({ block: "center" }),
    );
    await page.waitForFunction(
      () => document.querySelector("[data-testid='benchmark-render-heavy']"),
      null,
      { timeout: 15_000 },
    );
    await page.getByTestId("benchmark-render-heavy").click();
    await page.waitForFunction(() =>
      document
        .querySelector("[data-testid='benchmark-heavy-report']")
        ?.textContent?.includes("Rendered"),
    );
    await page.waitForLoadState("networkidle");

    const allResponses = (await Promise.all(responsePromises)).filter(Boolean);
    const added = allResponses.slice(initialCount);
    const measure = await page.evaluate(() => {
      const entry = performance.getEntriesByName(
        "live-islands-benchmark-heavy",
      )[0];

      return entry
        ? {
            duration: Math.round(entry.duration),
            startTime: Math.round(entry.startTime),
          }
        : null;
    });

    interaction = {
      network: summarizeResponses(added),
      measure,
      loadedHeavyLibraries: added
        .map((response) => response.url)
        .filter((url) => /pdf|katex/i.test(url))
        .map((url) => url.replace(baseURL, "")),
    };
  }

  const manifest = await page.evaluate(
    () => window.__liveIslandsPrefetch?.manifest?.() || [],
  );
  const performanceSummary = await page.evaluate(() => {
    const navigation = performance.getEntriesByType("navigation")[0];

    return navigation
      ? {
          domContentLoaded: Math.round(navigation.domContentLoadedEventEnd),
          load: Math.round(navigation.loadEventEnd),
          transferSize: navigation.transferSize,
          encodedBodySize: navigation.encodedBodySize,
          decodedBodySize: navigation.decodedBodySize,
        }
      : null;
  });
  const modulepreloadLinks = await page.evaluate(() =>
    [...document.querySelectorAll('link[rel="modulepreload"]')].map(
      (link) => link.href,
    ),
  );
  const runtimeSummary = await runtimeMetrics(page);

  await context.close();

  return {
    path: pathname,
    navigationMs,
    network: summarizeResponses(initialResponses),
    performance: performanceSummary,
    runtime: runtimeSummary,
    modulepreloadLinks,
    browserErrors,
    manifest: manifest.map((island) => ({
      page: island.page,
      framework: island.framework,
      name: island.name,
      client: island.client,
      prefetch: island.prefetch,
      ssr: island.ssr,
      serverOnly: island.serverOnly,
      deferred: island.deferred,
    })),
    ssr: {
      containsServerReport: html.includes("Server-only executive summary"),
      containsSsrProof: html.includes("Benchmark SSR proof"),
      containsDeferredFallback: html.includes(
        "Loading deferred benchmark report",
      ),
      containsDeferredReport: html.includes("Deferred server island report"),
      containsWorkbenchButton: html.includes("Render PDF + KaTeX"),
      serverReportHasHook: /id="benchmark_server_report"[^>]*phx-hook/.test(
        html,
      ),
      deferredReportHasHook: /id="benchmark_deferred_report"[^>]*phx-hook/.test(
        html,
      ),
      htmlBytes: Buffer.byteLength(html),
    },
    deferred: {
      network: summarizeResponses(deferredResponses),
      loadedCount: runtimeSummary.deferred?.loadedCount || 0,
      errorCount: runtimeSummary.deferred?.errorCount || 0,
      lastLoaded: runtimeSummary.deferred?.lastLoaded ?? null,
      loadSpan: runtimeSummary.deferred?.loadSpan ?? null,
    },
    interaction,
  };
}

async function collectScenario(browser, pathname, options = {}) {
  const runs = [];

  for (let index = 0; index < sampleCount; index += 1) {
    const sample = await collectPage(browser, pathname, options);
    sample.sampleIndex = index + 1;
    runs.push(sample);
  }

  const representative = medianRun(runs, (sample) => sample.network.totalBytes);

  return {
    ...representative,
    sampleCount: runs.length,
    samples: runs,
    stats: summarizePageSamples(runs),
    browserErrors: runs.flatMap((sample) =>
      sample.browserErrors.map((error) => ({
        ...error,
        sampleIndex: sample.sampleIndex,
      })),
    ),
  };
}

async function collectRouteFlow(browser) {
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    serviceWorkers: "block",
  });
  const page = await context.newPage();
  const { responsePromises, browserErrors } = attachDiagnostics(page);

  await page.goto(`${baseURL}/capabilities`, { waitUntil: "networkidle" });
  await page.waitForFunction(() =>
    window.__liveIslandsPrefetch
      ?.manifest?.()
      ?.some((island) => island.name === "Capabilities"),
  );

  const beforeManifest = await islandManifest(page);
  await Promise.all(responsePromises);
  const initialCount = responsePromises.length;

  const startedAt = Date.now();
  await page.getByRole("link", { name: "Benchmarks" }).click();
  await page.waitForURL(`${baseURL}/benchmarks`);
  await page.waitForFunction(() =>
    window.__liveIslandsPrefetch
      ?.manifest?.()
      ?.some((island) => island.name === "BenchmarkWorkbench"),
  );
  await page.locator("#benchmark_workbench").waitFor({ state: "attached" });
  await page.locator("#benchmark_vue_probe").waitFor({ state: "attached" });
  await page.getByTestId("benchmark-deferred-report").waitFor();
  await page
    .locator("#benchmark_vue_probe")
    .scrollIntoViewIfNeeded({ timeout: 10_000 });
  await page.locator("[data-testid='benchmark-render-heavy']").waitFor();
  await page.locator("[data-testid='benchmark-vue-probe']").waitFor();
  await page.waitForLoadState("networkidle");
  const navigationMs = Date.now() - startedAt;

  const allResponses = (await Promise.all(responsePromises)).filter(Boolean);
  const added = allResponses.slice(initialCount);
  const afterManifest = await islandManifest(page);

  await context.close();

  return {
    name: "capabilities-to-benchmarks",
    from: "/capabilities",
    to: "/benchmarks",
    navigationMs,
    network: summarizeResponses(added),
    beforeManifest,
    afterManifest,
    browserErrors,
    loadedHeavyLibraries: added
      .map((response) => response.url)
      .filter((url) => /pdf|katex/i.test(url))
      .map((url) => url.replace(baseURL, "")),
  };
}

const simplePropsRequest = (url) =>
  url.includes("/react-components/simple-props.jsx") ||
  /\/simple-props-[\w-]+\.js/.test(url);

async function collectIntentPrefetch(browser) {
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    serviceWorkers: "block",
  });
  const page = await context.newPage();
  await installRuntimeProbe(page);
  const { responsePromises, browserErrors } = attachDiagnostics(page);

  await page.goto(`${baseURL}/capabilities`, { waitUntil: "networkidle" });
  await page.waitForFunction(() =>
    window.__liveIslandsPrefetch
      ?.manifest?.()
      ?.some((island) => island.name === "SimpleProps"),
  );
  await page.waitForLoadState("networkidle");

  const beforeResponses = (await Promise.all([...responsePromises])).filter(
    Boolean,
  );
  const beforeModulepreloadLinks = await page.evaluate(() =>
    [...document.querySelectorAll('link[rel="modulepreload"]')].map(
      (link) => link.href,
    ),
  );
  const beforeModulepreloadSet = new Set(beforeModulepreloadLinks);
  const initialCount = responsePromises.length;

  const startedAt = Date.now();
  await page.locator("#intent-prefetch-probe").evaluate((el) => {
    el.dispatchEvent(new PointerEvent("pointerenter"));
  });
  await page.waitForFunction(() =>
    window.__liveIslandsBenchmarkRuntime?.prefetch?.loaded?.some(
      (event) => event.name === "SimpleProps",
    ),
  );
  await page.waitForLoadState("networkidle");
  const durationMs = Date.now() - startedAt;

  const allResponses = (await Promise.all([...responsePromises])).filter(
    Boolean,
  );
  const added = allResponses.slice(initialCount);
  const runtimeSummary = await runtimeMetrics(page);
  const modulepreloadLinks = await page.evaluate(() =>
    [...document.querySelectorAll('link[rel="modulepreload"]')].map(
      (link) => link.href,
    ),
  );
  const manifest = await islandManifest(page);

  await context.close();

  return {
    name: "intent-prefetch",
    path: "/capabilities",
    target: "SimpleProps",
    trigger: "pointerenter",
    durationMs,
    initialNetwork: summarizeResponses(beforeResponses),
    network: summarizeResponses(added),
    initialLoadedTarget: beforeResponses.some((response) =>
      simplePropsRequest(response.url),
    ),
    loadedTarget: added.some((response) => simplePropsRequest(response.url)),
    modulepreloadLinks: modulepreloadLinks.filter(
      (url) => !beforeModulepreloadSet.has(url),
    ),
    runtime: runtimeSummary.prefetch,
    manifest,
    browserErrors,
  };
}

async function islandManifest(page) {
  const manifest = await page.evaluate(
    () => window.__liveIslandsPrefetch?.manifest?.() || [],
  );

  return manifest.map((island) => ({
    page: island.page,
    framework: island.framework,
    name: island.name,
    client: island.client,
    prefetch: island.prefetch,
    ssr: island.ssr,
    serverOnly: island.serverOnly,
    deferred: island.deferred,
  }));
}

function medianRun(samples, metric) {
  return [...samples].sort((left, right) => {
    const metricDelta = metric(left) - metric(right);
    if (metricDelta !== 0) return metricDelta;
    return left.navigationMs - right.navigationMs;
  })[Math.floor((samples.length - 1) / 2)];
}

function summarizePageSamples(samples) {
  const interactionSamples = samples
    .map((sample) => sample.interaction)
    .filter(Boolean);

  return {
    navigationMs: numericStats(samples.map((sample) => sample.navigationMs)),
    network: {
      totalBytes: numericStats(
        samples.map((sample) => sample.network.totalBytes),
      ),
      uniqueBytes: numericStats(
        samples.map((sample) => sample.network.uniqueBytes),
      ),
      duplicateBytes: numericStats(
        samples.map((sample) => sample.network.duplicateBytes),
      ),
      jsBytes: numericStats(samples.map((sample) => sample.network.jsBytes)),
      cssBytes: numericStats(samples.map((sample) => sample.network.cssBytes)),
    },
    performance: {
      domContentLoaded: numericStats(
        samples.map((sample) => sample.performance?.domContentLoaded),
      ),
      load: numericStats(samples.map((sample) => sample.performance?.load)),
      encodedBodySize: numericStats(
        samples.map((sample) => sample.performance?.encodedBodySize),
      ),
      decodedBodySize: numericStats(
        samples.map((sample) => sample.performance?.decodedBodySize),
      ),
    },
    runtime: {
      firstContentfulPaint: numericStats(
        samples.map((sample) => sample.runtime?.firstContentfulPaint),
      ),
      largestContentfulPaint: numericStats(
        samples.map((sample) => sample.runtime?.largestContentfulPaint),
      ),
      hydratedCount: numericStats(
        samples.map((sample) => sample.runtime?.islands?.hydratedCount),
      ),
      lastHydrated: numericStats(
        samples.map((sample) => sample.runtime?.islands?.lastHydrated),
      ),
      hydrationSpan: numericStats(
        samples.map((sample) => sample.runtime?.islands?.hydrationSpan),
      ),
      deferredLastLoaded: numericStats(
        samples.map((sample) => sample.runtime?.deferred?.lastLoaded),
      ),
      deferredLoadSpan: numericStats(
        samples.map((sample) => sample.runtime?.deferred?.loadSpan),
      ),
      prefetchLoadedCount: numericStats(
        samples.map((sample) => sample.runtime?.prefetch?.loadedCount),
      ),
      prefetchModulepreloadedCount: numericStats(
        samples.map((sample) => sample.runtime?.prefetch?.modulepreloadedCount),
      ),
    },
    interaction:
      interactionSamples.length > 0
        ? {
            totalBytes: numericStats(
              interactionSamples.map((sample) => sample.network.totalBytes),
            ),
            jsBytes: numericStats(
              interactionSamples.map((sample) => sample.network.jsBytes),
            ),
            duration: numericStats(
              interactionSamples.map((sample) => sample.measure?.duration),
            ),
          }
        : null,
  };
}

function numericStats(values) {
  const numbers = values
    .filter((value) => typeof value === "number" && Number.isFinite(value))
    .sort((left, right) => left - right);

  if (numbers.length === 0) return null;

  const sum = numbers.reduce((total, value) => total + value, 0);

  return {
    min: numbers[0],
    median: numbers[Math.floor((numbers.length - 1) / 2)],
    max: numbers[numbers.length - 1],
    mean: Math.round(sum / numbers.length),
  };
}

function readGitRevision() {
  try {
    return execFileSync("git", ["rev-parse", "--short", "HEAD"], {
      cwd: root,
      encoding: "utf8",
    }).trim();
  } catch (_error) {
    return null;
  }
}

function benchmarkEnvironment(browser) {
  const rootPackage = readJson(join(root, "package.json"));
  const assetsPackage = readJson(join(exampleRoot, "assets/package.json"));
  const cpu = cpus()[0];

  return {
    system: {
      platform: platform(),
      type: type(),
      release: release(),
      arch: arch(),
      cpuCount: cpus().length,
      cpuModel: cpu?.model || null,
      totalMemoryBytes: totalmem(),
    },
    runtimes: {
      node: process.version,
      npm: commandOutput("npm", ["--version"]),
      elixir: commandOutput("elixir", ["--version"]),
      erlangOtp: commandOutput("erl", [
        "-noshell",
        "-eval",
        'io:format("~s", [erlang:system_info(otp_release)]), halt().',
      ]),
      playwright: commandOutput("npx", ["playwright", "--version"]),
      chromium: browser.version(),
    },
    packages: {
      liveIslands: rootPackage.version,
      rootPlaywright: dependencyVersion(rootPackage, "@playwright/test"),
      examplePhoenix: dependencyVersion(assetsPackage, "phoenix"),
      exampleLiveView: dependencyVersion(assetsPackage, "phoenix_live_view"),
      exampleReact: dependencyVersion(assetsPackage, "react"),
      exampleVue: dependencyVersion(assetsPackage, "vue"),
      exampleVite: dependencyVersion(assetsPackage, "vite"),
      exampleTailwind: dependencyVersion(assetsPackage, "tailwindcss"),
      exampleKatex: dependencyVersion(assetsPackage, "katex"),
      examplePdfjs: dependencyVersion(assetsPackage, "pdfjs-dist"),
    },
    benchmark: {
      command: ["node", "benchmarks/run.mjs", ...process.argv.slice(2)].join(
        " ",
      ),
      mixEnv: "prod",
      port,
      sampleCount,
      skipBuild,
      skipFlow,
      budgetPath: relative(root, resolve(root, budgetPath)),
      comparePath: comparePath
        ? relative(root, resolve(root, comparePath))
        : null,
    },
    github: {
      ci: Boolean(process.env.CI),
      repository: process.env.GITHUB_REPOSITORY || null,
      workflow: process.env.GITHUB_WORKFLOW || null,
      runId: process.env.GITHUB_RUN_ID || null,
      runAttempt: process.env.GITHUB_RUN_ATTEMPT || null,
      eventName: process.env.GITHUB_EVENT_NAME || null,
      ref: process.env.GITHUB_REF || null,
      refName: process.env.GITHUB_REF_NAME || null,
      sha: process.env.GITHUB_SHA || null,
      runnerOs: process.env.RUNNER_OS || null,
      runnerArch: process.env.RUNNER_ARCH || null,
    },
  };
}

function assertBenchmarks(result) {
  const failures = [];
  const benchmarkPage = result.pages.benchmarks;
  const routeFlow = result.flows?.capabilitiesToBenchmarks;
  const intentPrefetch = result.flows?.intentPrefetch;

  if (!benchmarkPage.ssr.containsServerReport) {
    failures.push("server-only SSR report was missing from initial HTML");
  }
  if (!benchmarkPage.ssr.containsSsrProof) {
    failures.push("SSR summary was missing from initial HTML");
  }
  if (!benchmarkPage.ssr.containsDeferredFallback) {
    failures.push(
      "deferred server island fallback was missing from initial HTML",
    );
  }
  if (benchmarkPage.ssr.containsDeferredReport) {
    failures.push("deferred server island final HTML leaked into initial HTML");
  }
  if (benchmarkPage.ssr.containsWorkbenchButton) {
    failures.push(
      "non-SSR heavy workbench leaked interactive HTML into initial HTML",
    );
  }
  if (benchmarkPage.ssr.serverReportHasHook) {
    failures.push("server-only report unexpectedly has a LiveView hook");
  }
  if (benchmarkPage.ssr.deferredReportHasHook) {
    failures.push("deferred server island unexpectedly has a LiveView hook");
  }
  if (benchmarkPage.deferred.loadedCount !== 1) {
    failures.push(
      `deferred server island loaded ${benchmarkPage.deferred.loadedCount} times instead of once`,
    );
  }
  if (benchmarkPage.deferred.network.count !== 1) {
    failures.push(
      `deferred server island fetched ${benchmarkPage.deferred.network.count} responses instead of one`,
    );
  }
  if (benchmarkPage.deferred.errorCount > 0) {
    failures.push("deferred server island emitted runtime errors");
  }
  if (benchmarkPage.deferred.network.failedResponses.length > 0) {
    failures.push(
      `deferred server island loaded failed responses: ${benchmarkPage.deferred.network.failedResponses
        .map((response) => `${response.status} ${response.url}`)
        .join("; ")}`,
    );
  }
  if (
    benchmarkPage.manifest.some(
      (island) => island.name === "Capabilities" || island.name === "Counter",
    )
  ) {
    failures.push(
      "benchmark page manifest included islands from another route",
    );
  }
  if (!benchmarkPage.interaction?.loadedHeavyLibraries.length) {
    failures.push("heavy interaction did not load PDF.js or KaTeX chunks");
  }
  if (benchmarkPage.network.failedResponses.length > 0) {
    failures.push(
      `benchmark page loaded failed responses: ${benchmarkPage.network.failedResponses
        .map((response) => `${response.status} ${response.url}`)
        .join("; ")}`,
    );
  }
  if (benchmarkPage.browserErrors.length > 0) {
    failures.push(
      `benchmark page emitted browser errors: ${benchmarkPage.browserErrors
        .map((error) => error.text)
        .join("; ")}`,
    );
  }
  if (routeFlow) {
    if (
      routeFlow.afterManifest.some(
        (island) => island.name === "Capabilities" || island.name === "Counter",
      )
    ) {
      failures.push("route flow kept islands from the previous page manifest");
    }
    if (routeFlow.loadedHeavyLibraries.length > 0) {
      failures.push("route flow loaded PDF.js or KaTeX before user intent");
    }
    if (routeFlow.network.failedResponses.length > 0) {
      failures.push(
        `route flow loaded failed responses: ${routeFlow.network.failedResponses
          .map((response) => `${response.status} ${response.url}`)
          .join("; ")}`,
      );
    }
    if (routeFlow.browserErrors.length > 0) {
      failures.push(
        `route flow emitted browser errors: ${routeFlow.browserErrors
          .map((error) => error.text)
          .join("; ")}`,
      );
    }
  }
  if (intentPrefetch) {
    if (intentPrefetch.initialLoadedTarget) {
      failures.push("intent prefetch target loaded before explicit intent");
    }
    if (!intentPrefetch.loadedTarget) {
      failures.push("intent prefetch did not load its target after intent");
    }
    if (intentPrefetch.modulepreloadLinks.length === 0) {
      failures.push("intent prefetch did not insert modulepreload links");
    }
    if (
      !intentPrefetch.runtime.loaded.some(
        (event) =>
          event.name === intentPrefetch.target &&
          event.policy === "intent" &&
          event.trigger === intentPrefetch.trigger &&
          event.priority === "high",
      )
    ) {
      failures.push("intent prefetch did not emit high-priority load evidence");
    }
    if (intentPrefetch.runtime.errorCount > 0) {
      failures.push("intent prefetch emitted runtime errors");
    }
    if (intentPrefetch.network.failedResponses.length > 0) {
      failures.push(
        `intent prefetch loaded failed responses: ${intentPrefetch.network.failedResponses
          .map((response) => `${response.status} ${response.url}`)
          .join("; ")}`,
      );
    }
    if (intentPrefetch.browserErrors.length > 0) {
      failures.push(
        `intent prefetch emitted browser errors: ${intentPrefetch.browserErrors
          .map((error) => error.text)
          .join("; ")}`,
      );
    }
  }

  return failures;
}

function compare(previous, current) {
  const metric = (name, before, after, unit = "bytes") => {
    if (
      typeof before !== "number" ||
      !Number.isFinite(before) ||
      typeof after !== "number" ||
      !Number.isFinite(after)
    ) {
      return null;
    }

    return { name, before, after, unit };
  };

  const fields = [
    metric(
      "home total",
      previous.pages.home.network.totalBytes,
      current.pages.home.network.totalBytes,
    ),
    metric(
      "home unique total",
      previous.pages.home.network.uniqueBytes ??
        previous.pages.home.network.totalBytes,
      current.pages.home.network.uniqueBytes,
    ),
    metric(
      "home first contentful paint",
      previous.pages.home.runtime?.firstContentfulPaint,
      current.pages.home.runtime?.firstContentfulPaint,
      "ms",
    ),
    metric(
      "home largest contentful paint",
      previous.pages.home.runtime?.largestContentfulPaint,
      current.pages.home.runtime?.largestContentfulPaint,
      "ms",
    ),
    metric(
      "home last island hydrated",
      previous.pages.home.runtime?.islands?.lastHydrated,
      current.pages.home.runtime?.islands?.lastHydrated,
      "ms",
    ),
    metric(
      "benchmark initial total",
      previous.pages.benchmarks.network.totalBytes,
      current.pages.benchmarks.network.totalBytes,
    ),
    metric(
      "benchmark initial unique total",
      previous.pages.benchmarks.network.uniqueBytes ??
        previous.pages.benchmarks.network.totalBytes,
      current.pages.benchmarks.network.uniqueBytes,
    ),
    metric(
      "benchmark initial JS",
      previous.pages.benchmarks.network.jsBytes,
      current.pages.benchmarks.network.jsBytes,
    ),
    metric(
      "benchmark first contentful paint",
      previous.pages.benchmarks.runtime?.firstContentfulPaint,
      current.pages.benchmarks.runtime?.firstContentfulPaint,
      "ms",
    ),
    metric(
      "benchmark largest contentful paint",
      previous.pages.benchmarks.runtime?.largestContentfulPaint,
      current.pages.benchmarks.runtime?.largestContentfulPaint,
      "ms",
    ),
    metric(
      "benchmark last island hydrated",
      previous.pages.benchmarks.runtime?.islands?.lastHydrated,
      current.pages.benchmarks.runtime?.islands?.lastHydrated,
      "ms",
    ),
    metric(
      "benchmark deferred last loaded",
      previous.pages.benchmarks.runtime?.deferred?.lastLoaded,
      current.pages.benchmarks.runtime?.deferred?.lastLoaded,
      "ms",
    ),
    metric(
      "benchmark deferred HTML",
      previous.pages.benchmarks.deferred?.network?.totalBytes,
      current.pages.benchmarks.deferred?.network?.totalBytes,
    ),
    metric(
      "heavy interaction JS",
      previous.pages.benchmarks.interaction.network.jsBytes,
      current.pages.benchmarks.interaction.network.jsBytes,
    ),
    metric(
      "heavy interaction duration",
      previous.pages.benchmarks.interaction.measure?.duration,
      current.pages.benchmarks.interaction.measure?.duration,
      "ms",
    ),
    metric(
      "artifact gzip total",
      previous.artifacts.totals.gzipBytes,
      current.artifacts.totals.gzipBytes,
    ),
  ].filter(Boolean);

  if (
    previous.flows?.capabilitiesToBenchmarks &&
    current.flows?.capabilitiesToBenchmarks
  ) {
    fields.push(
      metric(
        "capabilities-to-benchmarks total",
        previous.flows.capabilitiesToBenchmarks.network.totalBytes,
        current.flows.capabilitiesToBenchmarks.network.totalBytes,
      ),
      metric(
        "capabilities-to-benchmarks JS",
        previous.flows.capabilitiesToBenchmarks.network.jsBytes,
        current.flows.capabilitiesToBenchmarks.network.jsBytes,
      ),
    );
  }
  if (previous.flows?.intentPrefetch && current.flows?.intentPrefetch) {
    fields.push(
      metric(
        "intent prefetch total",
        previous.flows.intentPrefetch.network.totalBytes,
        current.flows.intentPrefetch.network.totalBytes,
      ),
      metric(
        "intent prefetch duration",
        previous.flows.intentPrefetch.durationMs,
        current.flows.intentPrefetch.durationMs,
        "ms",
      ),
    );
  }

  return fields.filter(Boolean).map(({ name, before, after, unit }) => ({
    name,
    before,
    after,
    unit,
    delta: after - before,
    deltaPercent: before
      ? Number((((after - before) / before) * 100).toFixed(2))
      : null,
  }));
}

function budgetFailures(result, budget) {
  if (!budget) return [];

  const checks = [
    [
      "home total bytes",
      result.pages.home.network.totalBytes,
      budget.home?.maxTotalBytes,
    ],
    [
      "home unique bytes",
      result.pages.home.network.uniqueBytes,
      budget.home?.maxUniqueBytes,
    ],
    [
      "benchmark initial total bytes",
      result.pages.benchmarks.network.totalBytes,
      budget.benchmarks?.maxInitialTotalBytes,
    ],
    [
      "benchmark initial unique bytes",
      result.pages.benchmarks.network.uniqueBytes,
      budget.benchmarks?.maxInitialUniqueBytes,
    ],
    [
      "benchmark initial JS bytes",
      result.pages.benchmarks.network.jsBytes,
      budget.benchmarks?.maxInitialJsBytes,
    ],
    [
      "benchmark heavy interaction total bytes",
      result.pages.benchmarks.interaction.network.totalBytes,
      budget.benchmarks?.maxHeavyInteractionTotalBytes,
    ],
    [
      "heavy interaction JS bytes",
      result.pages.benchmarks.interaction.network.jsBytes,
      budget.benchmarks?.maxHeavyInteractionJsBytes,
    ],
    [
      "artifact gzip bytes",
      result.artifacts.totals.gzipBytes,
      budget.artifacts?.maxGzipBytes,
    ],
    [
      "app entry bytes",
      result.artifacts.app?.bytes,
      budget.artifacts?.maxAppBytes,
    ],
    [
      "home largest contentful paint",
      result.pages.home.runtime?.largestContentfulPaint,
      budget.home?.maxLargestContentfulPaintMs,
    ],
    [
      "home last island hydrated",
      result.pages.home.runtime?.islands?.lastHydrated,
      budget.home?.maxLastHydratedMs,
    ],
    [
      "benchmark largest contentful paint",
      result.pages.benchmarks.runtime?.largestContentfulPaint,
      budget.benchmarks?.maxLargestContentfulPaintMs,
    ],
    [
      "benchmark last island hydrated",
      result.pages.benchmarks.runtime?.islands?.lastHydrated,
      budget.benchmarks?.maxLastHydratedMs,
    ],
    [
      "benchmark heavy interaction duration",
      result.pages.benchmarks.interaction.measure?.duration,
      budget.benchmarks?.maxHeavyInteractionDurationMs,
    ],
    [
      "benchmark deferred last loaded",
      result.pages.benchmarks.deferred?.lastLoaded,
      budget.benchmarks?.maxDeferredLastLoadedMs,
    ],
    [
      "benchmark deferred HTML bytes",
      result.pages.benchmarks.deferred?.network?.totalBytes,
      budget.benchmarks?.maxDeferredHtmlBytes,
    ],
  ];

  if (result.flows?.capabilitiesToBenchmarks) {
    checks.push(
      [
        "capabilities-to-benchmarks total bytes",
        result.flows.capabilitiesToBenchmarks.network.totalBytes,
        budget.flows?.capabilitiesToBenchmarks?.maxTotalBytes,
      ],
      [
        "capabilities-to-benchmarks JS bytes",
        result.flows.capabilitiesToBenchmarks.network.jsBytes,
        budget.flows?.capabilitiesToBenchmarks?.maxJsBytes,
      ],
    );
  }
  if (result.flows?.intentPrefetch) {
    checks.push(
      [
        "intent prefetch total bytes",
        result.flows.intentPrefetch.network.totalBytes,
        budget.flows?.intentPrefetch?.maxTotalBytes,
      ],
      [
        "intent prefetch duration",
        result.flows.intentPrefetch.durationMs,
        budget.flows?.intentPrefetch?.maxDurationMs,
      ],
    );
  }

  return checks
    .filter(([_name, actual, max]) => typeof max === "number" && actual > max)
    .map(([name, actual, max]) => `${name} ${actual} exceeded budget ${max}`);
}

function regressionFailures(result, budget) {
  const policy = budget?.regressions;
  if (!policy || !result.comparison) return [];

  const defaults = {
    maxDeltaPercent: policy.maxDeltaPercent,
    maxDeltaBytes: policy.maxDeltaBytes,
    maxDeltaMs: policy.maxDeltaMs,
  };

  return result.comparison.flatMap((row) => {
    if (row.delta <= 0) return [];

    const metricPolicy = policy.metrics?.[row.name] || {};
    const maxDeltaPercent =
      metricPolicy.maxDeltaPercent ?? defaults.maxDeltaPercent;
    const maxDelta =
      row.unit === "ms"
        ? (metricPolicy.maxDeltaMs ?? defaults.maxDeltaMs)
        : (metricPolicy.maxDeltaBytes ?? defaults.maxDeltaBytes);

    const percentFailed =
      typeof maxDeltaPercent === "number" &&
      row.deltaPercent !== null &&
      row.deltaPercent > maxDeltaPercent;
    const absoluteFailed = typeof maxDelta === "number" && row.delta > maxDelta;

    if (percentFailed && absoluteFailed) {
      return [
        `${row.name} regressed by ${formatComparisonValue(
          row.delta,
          row.unit,
        )} (${row.deltaPercent}%)`,
      ];
    }

    return [];
  });
}

function formatBytes(value) {
  const sign = value < 0 ? "-" : "";
  const abs = Math.abs(value);

  if (abs < 1024) return `${sign}${abs} B`;
  if (abs < 1024 * 1024) return `${sign}${(abs / 1024).toFixed(1)} KiB`;
  return `${sign}${(abs / 1024 / 1024).toFixed(2)} MiB`;
}

function markdown(result) {
  const rows = [
    ["Home total", result.pages.home.network.totalBytes],
    ["Home unique URL total", result.pages.home.network.uniqueBytes],
    ["Benchmark initial total", result.pages.benchmarks.network.totalBytes],
    [
      "Benchmark initial unique URL total",
      result.pages.benchmarks.network.uniqueBytes,
    ],
    ["Benchmark initial JS", result.pages.benchmarks.network.jsBytes],
    [
      "Benchmark heavy interaction total",
      result.pages.benchmarks.interaction.network.totalBytes,
    ],
    [
      "Benchmark heavy interaction JS",
      result.pages.benchmarks.interaction.network.jsBytes,
    ],
    [
      "Benchmark deferred HTML",
      result.pages.benchmarks.deferred.network.totalBytes,
    ],
    result.flows.intentPrefetch
      ? [
          "Intent prefetch total",
          result.flows.intentPrefetch.network.totalBytes,
        ]
      : null,
    ["Vite artifact gzip total", result.artifacts.totals.gzipBytes],
  ].filter(Boolean);

  return [
    "# LiveIslands Benchmark Result",
    "",
    `- Commit: \`${result.commit || "unknown"}\``,
    `- Created: ${result.createdAt}`,
    `- Base URL: ${result.baseURL}`,
    `- Samples per page: ${result.sampleCount}`,
    ...environmentMarkdown(result),
    "",
    "## Summary",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    ...rows.map(([name, value]) => `| ${name} | ${formatBytes(value)} |`),
    ...comparisonMarkdown(result),
    "",
    "## SSR Assertions",
    "",
    `- Server-only report in initial HTML: ${result.pages.benchmarks.ssr.containsServerReport}`,
    `- SSR summary in initial HTML: ${result.pages.benchmarks.ssr.containsSsrProof}`,
    `- Deferred fallback in initial HTML: ${result.pages.benchmarks.ssr.containsDeferredFallback}`,
    `- Deferred final HTML absent from initial HTML: ${!result.pages.benchmarks.ssr.containsDeferredReport}`,
    `- Heavy non-SSR workbench absent from initial HTML: ${!result.pages.benchmarks.ssr.containsWorkbenchButton}`,
    `- Server-only report has no hook: ${!result.pages.benchmarks.ssr.serverReportHasHook}`,
    `- Deferred report has no hook: ${!result.pages.benchmarks.ssr.deferredReportHasHook}`,
    `- Browser errors: ${result.pages.benchmarks.browserErrors.length}`,
    "",
    "## Sample Stability",
    "",
    "| Metric | Min | Median | Max | Mean |",
    "| --- | ---: | ---: | ---: | ---: |",
    ...sampleStatsRows(result),
    "",
    "## Runtime Metrics",
    "",
    "| Page | FCP | LCP | Hydrated Islands | Last Hydrated | Deferred Loaded | Last Deferred | Prefetch Loaded | Modulepreloads |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ...runtimeRows(result),
    "",
    "## Largest Benchmark Initial Requests",
    "",
    "| Resource | Type | Bytes |",
    "| --- | --- | ---: |",
    ...result.pages.benchmarks.network.topUrls.map(
      (response) =>
        `| \`${response.url}\` | ${response.resourceType} | ${formatBytes(
          response.bytes,
        )} |`,
    ),
    "",
    "## Heavy Interaction Requests",
    "",
    "| Resource | Type | Bytes |",
    "| --- | --- | ---: |",
    ...result.pages.benchmarks.interaction.network.urls.map(
      (response) =>
        `| \`${response.url}\` | ${response.resourceType} | ${formatBytes(
          response.bytes,
        )} |`,
    ),
    ...routeFlowMarkdown(result),
    ...intentPrefetchMarkdown(result),
    "",
    "## Page Manifest",
    "",
    "```json",
    JSON.stringify(result.pages.benchmarks.manifest, null, 2),
    "```",
  ].join("\n");
}

function environmentMarkdown(result) {
  const environment = result.environment;
  if (!environment) return [];

  return [
    `- CI: ${environment.github.ci}`,
    `- OS: ${environment.system.type} ${environment.system.release} (${environment.system.arch})`,
    `- CPU: ${environment.system.cpuCount} x ${environment.system.cpuModel || "unknown"}`,
    `- Node: ${environment.runtimes.node}`,
    `- npm: ${environment.runtimes.npm || "unknown"}`,
    `- Elixir/OTP: ${elixirLine(environment.runtimes.elixir)} / ${environment.runtimes.erlangOtp || "unknown"}`,
    `- Playwright/Chromium: ${environment.runtimes.playwright || "unknown"} / ${environment.runtimes.chromium || "unknown"}`,
  ];
}

function firstLine(value) {
  return value?.split(/\r?\n/).find(Boolean) || "unknown";
}

function elixirLine(value) {
  return (
    value?.split(/\r?\n/).find((line) => line.startsWith("Elixir ")) ||
    firstLine(value)
  );
}

function runtimeRows(result) {
  return [
    ["Home", result.pages.home],
    ["Benchmarks", result.pages.benchmarks],
  ].map(([name, page]) => {
    const runtime = page.runtime || {};
    const islands = runtime.islands || {};
    const deferred = runtime.deferred || {};
    const prefetch = runtime.prefetch || {};

    return `| ${name} | ${formatOptional(runtime.firstContentfulPaint, "ms")} | ${formatOptional(runtime.largestContentfulPaint, "ms")} | ${islands.hydratedCount ?? 0} | ${formatOptional(islands.lastHydrated, "ms")} | ${deferred.loadedCount ?? 0} | ${formatOptional(deferred.lastLoaded, "ms")} | ${prefetch.loadedCount ?? 0} | ${prefetch.modulepreloadedCount ?? 0} |`;
  });
}

function sampleStatsRows(result) {
  const rows = [
    ["Home navigation", result.pages.home.stats.navigationMs, "ms"],
    ["Home total bytes", result.pages.home.stats.network.totalBytes, "bytes"],
    ["Home FCP", result.pages.home.stats.runtime.firstContentfulPaint, "ms"],
    ["Home LCP", result.pages.home.stats.runtime.largestContentfulPaint, "ms"],
    ["Benchmark navigation", result.pages.benchmarks.stats.navigationMs, "ms"],
    [
      "Benchmark total bytes",
      result.pages.benchmarks.stats.network.totalBytes,
      "bytes",
    ],
    [
      "Benchmark FCP",
      result.pages.benchmarks.stats.runtime.firstContentfulPaint,
      "ms",
    ],
    [
      "Benchmark LCP",
      result.pages.benchmarks.stats.runtime.largestContentfulPaint,
      "ms",
    ],
    [
      "Benchmark last hydrated",
      result.pages.benchmarks.stats.runtime.lastHydrated,
      "ms",
    ],
    [
      "Benchmark deferred loaded",
      result.pages.benchmarks.stats.runtime.deferredLastLoaded,
      "ms",
    ],
    [
      "Benchmark deferred span",
      result.pages.benchmarks.stats.runtime.deferredLoadSpan,
      "ms",
    ],
    [
      "Benchmark prefetch loaded",
      result.pages.benchmarks.stats.runtime.prefetchLoadedCount,
      "count",
    ],
    [
      "Benchmark modulepreloads",
      result.pages.benchmarks.stats.runtime.prefetchModulepreloadedCount,
      "count",
    ],
    [
      "Heavy interaction duration",
      result.pages.benchmarks.stats.interaction?.duration,
      "ms",
    ],
  ];

  return rows
    .filter(([_name, stats]) => stats)
    .map(
      ([name, stats, unit]) =>
        `| ${name} | ${formatStat(stats.min, unit)} | ${formatStat(
          stats.median,
          unit,
        )} | ${formatStat(stats.max, unit)} | ${formatStat(stats.mean, unit)} |`,
    );
}

function routeFlowMarkdown(result) {
  const flow = result.flows?.capabilitiesToBenchmarks;
  if (!flow) return [];

  return [
    "",
    "## Route Navigation Flow",
    "",
    `- Flow: \`${flow.from}\` -> \`${flow.to}\``,
    `- Navigation time: ${flow.navigationMs} ms`,
    `- Network total: ${formatBytes(flow.network.totalBytes)}`,
    `- Network JS: ${formatBytes(flow.network.jsBytes)}`,
    `- Heavy libraries loaded before intent: ${flow.loadedHeavyLibraries.length}`,
    "",
    "| After Navigation Manifest | Framework | Client | Prefetch | Server Only | Deferred |",
    "| --- | --- | --- | --- | --- | --- |",
    ...flow.afterManifest.map(
      (island) =>
        `| ${island.name} | ${island.framework} | ${island.client} | ${island.prefetch} | ${island.serverOnly} | ${island.deferred} |`,
    ),
  ];
}

function intentPrefetchMarkdown(result) {
  const flow = result.flows?.intentPrefetch;
  if (!flow) return [];

  const loadedEvent = flow.runtime.loaded.find(
    (event) => event.name === flow.target,
  );

  return [
    "",
    "## Intent Prefetch Flow",
    "",
    `- Page: \`${flow.path}\``,
    `- Target: \`${flow.target}\``,
    `- Trigger: \`${flow.trigger}\``,
    `- Loaded before intent: ${flow.initialLoadedTarget}`,
    `- Loaded after intent: ${flow.loadedTarget}`,
    `- Duration: ${flow.durationMs} ms`,
    `- Network total: ${formatBytes(flow.network.totalBytes)}`,
    `- Modulepreload links: ${flow.modulepreloadLinks.length}`,
    `- Runtime evidence: ${loadedEvent ? `${loadedEvent.policy}/${loadedEvent.trigger}/${loadedEvent.priority}` : "missing"}`,
  ];
}

function formatStat(value, unit) {
  if (unit === "count") return `${value}`;
  if (unit === "bytes") return formatBytes(value);
  return `${value} ${unit}`;
}

function formatOptional(value, unit) {
  if (typeof value !== "number" || !Number.isFinite(value)) return "n/a";
  return formatStat(value, unit);
}

function formatComparisonValue(value, unit) {
  return unit === "ms" ? `${value} ms` : formatBytes(value);
}

function comparisonMarkdown(result) {
  if (!result.comparison) return [];

  return [
    "",
    "## Comparison",
    "",
    "| Metric | Before | After | Delta | Delta % |",
    "| --- | ---: | ---: | ---: | ---: |",
    ...result.comparison.map(
      (row) =>
        `| ${row.name} | ${formatComparisonValue(
          row.before,
          row.unit,
        )} | ${formatComparisonValue(row.after, row.unit)} | ${formatComparisonValue(row.delta, row.unit)} | ${
          row.deltaPercent === null ? "n/a" : `${row.deltaPercent}%`
        } |`,
    ),
  ];
}

async function main() {
  if (!skipBuild) {
    run("npm", ["run", "build", "--prefix", "assets"], { cwd: exampleRoot });
    run("npm", ["run", "build-server", "--prefix", "assets"], {
      cwd: exampleRoot,
    });
    rmSync(join(exampleRoot, "priv/static/cache_manifest.json"), {
      force: true,
    });
    run("mix", ["phx.digest"], { cwd: exampleRoot, env: { MIX_ENV: "prod" } });
  }

  const server = startServer();
  let exitCode = 0;

  try {
    await waitForServer();
    const browser = await chromium.launch();

    try {
      const result = {
        version: 5,
        createdAt: new Date().toISOString(),
        commit: readGitRevision(),
        baseURL,
        sampleCount,
        environment: benchmarkEnvironment(browser),
        artifacts: buildArtifacts(),
        pages: {
          home: await collectScenario(browser, "/"),
          benchmarks: await collectScenario(browser, "/benchmarks", {
            heavyInteraction: true,
          }),
        },
        flows: skipFlow
          ? {}
          : {
              capabilitiesToBenchmarks: await collectRouteFlow(browser),
              intentPrefetch: await collectIntentPrefetch(browser),
            },
      };

      if (comparePath && existsSync(comparePath)) {
        result.comparison = compare(readJson(comparePath), result);
      }

      const budget = existsSync(budgetPath) ? readJson(budgetPath) : null;
      const failures = [
        ...assertBenchmarks(result),
        ...budgetFailures(result, budget),
        ...regressionFailures(result, budget),
      ];

      mkdirSync(dirname(outPath), { recursive: true });
      writeFileSync(outPath, `${JSON.stringify(result, null, 2)}\n`);
      writeFileSync(markdownPath, `${markdown(result)}\n`);

      console.log(`Benchmark JSON: ${relative(root, outPath)}`);
      console.log(`Benchmark Markdown: ${relative(root, markdownPath)}`);
      console.table([
        {
          metric: "home total",
          value: formatBytes(result.pages.home.network.totalBytes),
        },
        {
          metric: "benchmark initial total",
          value: formatBytes(result.pages.benchmarks.network.totalBytes),
        },
        {
          metric: "benchmark initial JS",
          value: formatBytes(result.pages.benchmarks.network.jsBytes),
        },
        {
          metric: "heavy interaction JS",
          value: formatBytes(
            result.pages.benchmarks.interaction.network.jsBytes,
          ),
        },
        {
          metric: "deferred HTML",
          value: formatBytes(
            result.pages.benchmarks.deferred.network.totalBytes,
          ),
        },
        {
          metric: "intent prefetch",
          value: result.flows.intentPrefetch
            ? formatBytes(result.flows.intentPrefetch.network.totalBytes)
            : "skipped",
        },
        {
          metric: "artifact gzip total",
          value: formatBytes(result.artifacts.totals.gzipBytes),
        },
      ]);

      if (failures.length > 0) {
        console.error("Benchmark failures:");
        failures.forEach((failure) => console.error(`- ${failure}`));
        exitCode = 1;
      }
    } finally {
      await browser.close();
    }
  } finally {
    if (!keepServer) server.kill("SIGTERM");
  }

  process.exit(exitCode);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
