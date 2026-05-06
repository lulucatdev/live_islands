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
const comparePath = args.get("compare");
const budgetPath = args.get("budget") || defaultBudgetPath;
const outPath = resolve(args.get("out") || join(resultsDir, "latest.json"));
const markdownPath = outPath.replace(/\.json$/, ".md");

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

async function collectPage(browser, pathname, options = {}) {
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    serviceWorkers: "block",
  });
  const page = await context.newPage();
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

  await context.close();

  return {
    path: pathname,
    navigationMs,
    network: summarizeResponses(initialResponses),
    performance: performanceSummary,
    browserErrors,
    manifest: manifest.map((island) => ({
      page: island.page,
      framework: island.framework,
      name: island.name,
      client: island.client,
      prefetch: island.prefetch,
      ssr: island.ssr,
      serverOnly: island.serverOnly,
    })),
    ssr: {
      containsServerReport: html.includes("Server-only executive summary"),
      containsSsrProof: html.includes("Benchmark SSR proof"),
      containsWorkbenchButton: html.includes("Render PDF + KaTeX"),
      serverReportHasHook: /id="benchmark_server_report"[^>]*phx-hook/.test(
        html,
      ),
      htmlBytes: Buffer.byteLength(html),
    },
    interaction,
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

function assertBenchmarks(result) {
  const failures = [];
  const benchmarkPage = result.pages.benchmarks;

  if (!benchmarkPage.ssr.containsServerReport) {
    failures.push("server-only SSR report was missing from initial HTML");
  }
  if (!benchmarkPage.ssr.containsSsrProof) {
    failures.push("SSR summary was missing from initial HTML");
  }
  if (benchmarkPage.ssr.containsWorkbenchButton) {
    failures.push(
      "non-SSR heavy workbench leaked interactive HTML into initial HTML",
    );
  }
  if (benchmarkPage.ssr.serverReportHasHook) {
    failures.push("server-only report unexpectedly has a LiveView hook");
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
  if (benchmarkPage.browserErrors.length > 0) {
    failures.push(
      `benchmark page emitted browser errors: ${benchmarkPage.browserErrors
        .map((error) => error.text)
        .join("; ")}`,
    );
  }

  return failures;
}

function compare(previous, current) {
  const fields = [
    [
      "home total",
      previous.pages.home.network.totalBytes,
      current.pages.home.network.totalBytes,
    ],
    [
      "home unique total",
      previous.pages.home.network.uniqueBytes ??
        previous.pages.home.network.totalBytes,
      current.pages.home.network.uniqueBytes,
    ],
    [
      "benchmark initial total",
      previous.pages.benchmarks.network.totalBytes,
      current.pages.benchmarks.network.totalBytes,
    ],
    [
      "benchmark initial unique total",
      previous.pages.benchmarks.network.uniqueBytes ??
        previous.pages.benchmarks.network.totalBytes,
      current.pages.benchmarks.network.uniqueBytes,
    ],
    [
      "benchmark initial JS",
      previous.pages.benchmarks.network.jsBytes,
      current.pages.benchmarks.network.jsBytes,
    ],
    [
      "heavy interaction JS",
      previous.pages.benchmarks.interaction.network.jsBytes,
      current.pages.benchmarks.interaction.network.jsBytes,
    ],
    [
      "artifact gzip total",
      previous.artifacts.totals.gzipBytes,
      current.artifacts.totals.gzipBytes,
    ],
  ];

  return fields.map(([name, before, after]) => ({
    name,
    before,
    after,
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
  ];

  return checks
    .filter(([_name, actual, max]) => typeof max === "number" && actual > max)
    .map(([name, actual, max]) => `${name} ${actual} exceeded budget ${max}`);
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
    ["Vite artifact gzip total", result.artifacts.totals.gzipBytes],
  ];

  return [
    "# LiveIslands Benchmark Result",
    "",
    `- Commit: \`${result.commit || "unknown"}\``,
    `- Created: ${result.createdAt}`,
    `- Base URL: ${result.baseURL}`,
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
    `- Heavy non-SSR workbench absent from initial HTML: ${!result.pages.benchmarks.ssr.containsWorkbenchButton}`,
    `- Server-only report has no hook: ${!result.pages.benchmarks.ssr.serverReportHasHook}`,
    `- Browser errors: ${result.pages.benchmarks.browserErrors.length}`,
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
    "",
    "## Page Manifest",
    "",
    "```json",
    JSON.stringify(result.pages.benchmarks.manifest, null, 2),
    "```",
  ].join("\n");
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
        `| ${row.name} | ${formatBytes(row.before)} | ${formatBytes(
          row.after,
        )} | ${formatBytes(row.delta)} | ${
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
        version: 1,
        createdAt: new Date().toISOString(),
        commit: readGitRevision(),
        baseURL,
        artifacts: buildArtifacts(),
        pages: {
          home: await collectPage(browser, "/"),
          benchmarks: await collectPage(browser, "/benchmarks", {
            heavyInteraction: true,
          }),
        },
      };

      const failures = [
        ...assertBenchmarks(result),
        ...budgetFailures(
          result,
          existsSync(budgetPath) ? readJson(budgetPath) : null,
        ),
      ];

      if (comparePath && existsSync(comparePath)) {
        result.comparison = compare(readJson(comparePath), result);
      }

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
