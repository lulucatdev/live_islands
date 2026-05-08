const STORE_KEY = "__liveIslandsBrowserBenchmark";
const ONLINE_MEASURE_NAME = "live-islands-benchmark-online";
const HEAVY_MEASURE_NAME = "live-islands-benchmark-heavy";

const nowIso = () => new Date().toISOString();

const benchmarkStore = () =>
  window[STORE_KEY] ||
  (window[STORE_KEY] = {
    events: [],
    installed: false,
    startedAt: nowIso(),
  });

const bytesFor = (entry) =>
  Math.max(
    0,
    Number(entry?.transferSize || 0),
    Number(entry?.encodedBodySize || 0),
    Number(entry?.decodedBodySize || 0),
  );

const classifyEntry = (entry) => {
  const name = entry?.name || "";
  const initiator = entry?.initiatorType || "";

  if (entry?.entryType === "navigation") return "document";
  if (initiator === "script" || /\.m?js($|\?)/.test(name)) return "script";
  if (initiator === "css" || /\.css($|\?)/.test(name)) return "style";
  if (initiator === "fetch" || initiator === "xmlhttprequest") return "fetch";
  if (initiator === "img" || /\.(png|jpg|jpeg|gif|svg|webp|ico)($|\?)/.test(name)) {
    return "image";
  }
  if (/\.(woff2?|ttf|otf)($|\?)/.test(name)) return "font";

  return initiator || "other";
};

const compactUrl = (url) => {
  try {
    const parsed = new URL(url, window.location.href);
    return `${parsed.pathname}${parsed.search}`;
  } catch (_error) {
    return url;
  }
};

const summarizeEntries = (entries) => {
  const rows = entries.map((entry) => ({
    url: compactUrl(entry.name || window.location.href),
    kind: classifyEntry(entry),
    bytes: bytesFor(entry),
    duration: Math.round(Number(entry.duration || 0)),
  }));

  const unique = new Map();
  rows.forEach((row) => {
    const previous = unique.get(row.url) || 0;
    unique.set(row.url, Math.max(previous, row.bytes));
  });

  const sumWhere = (predicate) =>
    rows
      .filter(predicate)
      .reduce((total, row) => total + Number(row.bytes || 0), 0);

  return {
    requestCount: rows.length,
    totalBytes: sumWhere(() => true),
    uniqueBytes: [...unique.values()].reduce((total, bytes) => total + bytes, 0),
    documentBytes: sumWhere((row) => row.kind === "document"),
    jsBytes: sumWhere((row) => row.kind === "script"),
    cssBytes: sumWhere((row) => row.kind === "style"),
    fetchBytes: sumWhere((row) => row.kind === "fetch"),
    imageBytes: sumWhere((row) => row.kind === "image"),
    fontBytes: sumWhere((row) => row.kind === "font"),
    topRequests: rows
      .slice()
      .sort((left, right) => right.bytes - left.bytes)
      .slice(0, 5),
  };
};

const navigationEntries = () => performance.getEntriesByType("navigation");
const resourceEntries = () => performance.getEntriesByType("resource");
const allNetworkEntries = () => [...navigationEntries(), ...resourceEntries()];

const timingValue = (entry, key) => {
  const value = Number(entry?.[key] || 0);
  return value > 0 ? Math.round(value) : null;
};

const collectPageTimings = () => {
  const nav = navigationEntries()[0];
  const fcp = performance.getEntriesByName("first-contentful-paint")[0];

  return {
    responseEnd: timingValue(nav, "responseEnd"),
    domContentLoaded: timingValue(nav, "domContentLoadedEventEnd"),
    loadEventEnd: timingValue(nav, "loadEventEnd"),
    firstContentfulPaint: timingValue(fcp, "startTime"),
  };
};

const wait = (ms) => new Promise((resolve) => window.setTimeout(resolve, ms));

const waitFor = async (callback, { timeout = 10_000, interval = 50 } = {}) => {
  const started = performance.now();

  while (performance.now() - started < timeout) {
    const value = callback();
    if (value) return value;
    await wait(interval);
  }

  return null;
};

const waitForElement = (selector, timeout = 10_000) =>
  waitFor(() => document.querySelector(selector), { timeout });

const heavyMeasure = () => {
  const entries = performance.getEntriesByName(HEAVY_MEASURE_NAME);
  const latest = entries[entries.length - 1];
  return latest
    ? {
        duration: Math.round(latest.duration),
        startTime: Math.round(latest.startTime),
      }
    : null;
};

const collectRuntime = () => {
  const store = benchmarkStore();
  const events = store.events || [];
  const count = (type) => events.filter((event) => event.type === type).length;
  const manifest = window.__liveIslandsPrefetch?.manifest?.() || [];

  return {
    eventCount: events.length,
    mountedCount: count("live-islands:mounted"),
    hydratedCount: count("live-islands:hydrated"),
    deferredLoadedCount: count("live-islands:deferred:load"),
    prefetchLoadedCount: count("live-islands:prefetch:load"),
    modulepreloadCount: count("live-islands:prefetch:modulepreload"),
    errorCount: events.filter((event) => event.type.endsWith(":error")).length,
    manifest,
  };
};

export async function runOnlineBenchmark() {
  benchmarkStore();
  performance.clearMarks(`${ONLINE_MEASURE_NAME}-start`);
  performance.clearMarks(`${ONLINE_MEASURE_NAME}-end`);
  performance.clearMeasures(ONLINE_MEASURE_NAME);
  performance.clearMarks("live-islands-benchmark-heavy-start");
  performance.clearMarks("live-islands-benchmark-heavy-end");
  performance.clearMeasures(HEAVY_MEASURE_NAME);

  const startedAt = performance.now();
  const beforeResources = resourceEntries().length;
  const initialNetwork = summarizeEntries(allNetworkEntries());
  const initialTimings = collectPageTimings();

  performance.mark(`${ONLINE_MEASURE_NAME}-start`);

  await waitFor(
    () => document.querySelector("[data-testid='benchmark-deferred-report']"),
    { timeout: 8_000 },
  );

  const heavyButton = await waitForElement(
    "[data-testid='benchmark-render-heavy']",
    10_000,
  );

  if (!heavyButton) {
    throw new Error("Benchmark workbench was not ready.");
  }

  heavyButton.scrollIntoView({ block: "center", behavior: "instant" });
  await wait(50);
  heavyButton.click();

  await waitFor(
    () =>
      heavyMeasure() ||
      document
        .querySelector("[data-testid='benchmark-heavy-report']")
        ?.textContent?.includes("Rendered"),
    { timeout: 15_000 },
  );

  const vueProbe = document.querySelector("#benchmark_vue_probe");
  vueProbe?.scrollIntoView({ block: "center", behavior: "instant" });
  await waitFor(
    () =>
      (benchmarkStore().events || []).some(
        (event) =>
          event.type === "live-islands:hydrated" &&
          event.framework === "vue" &&
          event.name === "benchmark-probe",
      ) || document.querySelector("[data-testid='benchmark-vue-probe']"),
    { timeout: 8_000 },
  );

  performance.mark(`${ONLINE_MEASURE_NAME}-end`);
  performance.measure(
    ONLINE_MEASURE_NAME,
    `${ONLINE_MEASURE_NAME}-start`,
    `${ONLINE_MEASURE_NAME}-end`,
  );

  const onlineMeasure = performance.getEntriesByName(ONLINE_MEASURE_NAME).at(-1);
  const interactionNetwork = summarizeEntries(
    resourceEntries().slice(beforeResources),
  );

  document
    .querySelector("#benchmark-online-runner")
    ?.scrollIntoView({ block: "start", behavior: "instant" });

  return {
    measuredAt: nowIso(),
    mode: "browser-online",
    page: {
      path: `${window.location.pathname}${window.location.search}`,
      network: initialNetwork,
      timings: initialTimings,
    },
    interaction: {
      duration: heavyMeasure()?.duration || Math.round(onlineMeasure?.duration || 0),
      totalDuration: Math.round(performance.now() - startedAt),
      network: interactionNetwork,
      heavy: heavyMeasure(),
      status:
        document.querySelector("[data-testid='benchmark-heavy-report']")
          ?.textContent || "",
    },
    runtime: collectRuntime(),
  };
}
