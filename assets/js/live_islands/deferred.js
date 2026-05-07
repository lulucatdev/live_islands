import { describeIslandElement, warnLiveIslands } from "./diagnostics.js";

const DEFER_SELECTOR = "[data-live-islands-defer-src]";

const deferred = new WeakMap();
const loaded = new Set();

const dispatch = (name, el, detail = {}) => {
  window.dispatchEvent(
    new CustomEvent(`live-islands:deferred:${name}`, {
      detail: { el, ...detail },
    }),
  );
};

const deferredElements = (root = document) => {
  const elements = [];

  if (root.matches?.(DEFER_SELECTOR)) elements.push(root);
  if (root.querySelectorAll)
    elements.push(...root.querySelectorAll(DEFER_SELECTOR));

  return elements;
};

async function fetchDeferred(el) {
  if (deferred.has(el)) return deferred.get(el);
  if (el.getAttribute("data-live-islands-defer-state") === "loaded")
    return null;

  const src = el.getAttribute("data-live-islands-defer-src");
  if (!src) return null;

  const key =
    el.id ||
    `${el.getAttribute("data-framework")}:${el.getAttribute("data-name")}:${src}`;
  if (loaded.has(key)) {
    el.setAttribute("data-live-islands-defer-state", "loaded");
    el.removeAttribute("data-live-islands-defer-src");
    return null;
  }

  const startedAt = performance.now();
  const timeout = Number(
    el.getAttribute("data-live-islands-defer-timeout") || 0,
  );
  const controller = new AbortController();
  const timeoutId =
    timeout > 0 ? window.setTimeout(() => controller.abort(), timeout) : null;

  el.setAttribute("data-live-islands-defer-state", "loading");
  dispatch("start", el);

  const promise = fetch(src, {
    credentials: "same-origin",
    headers: { accept: "text/html" },
    signal: controller.signal,
  })
    .then(async (response) => {
      const html = await response.text();
      if (!response.ok) {
        throw new Error(
          `HTTP ${response.status}: ${html || response.statusText}`,
        );
      }

      el.innerHTML = html;
      el.setAttribute("data-live-islands-defer-state", "loaded");
      el.removeAttribute("data-live-islands-defer-src");
      loaded.add(key);

      dispatch("load", el, {
        duration: Math.round(performance.now() - startedAt),
        bytes: new TextEncoder().encode(html).length,
      });

      return html;
    })
    .catch((error) => {
      el.setAttribute("data-live-islands-defer-state", "error");
      dispatch("error", el, {
        duration: Math.round(performance.now() - startedAt),
        message: error?.message || String(error),
      });
      warnLiveIslands(
        `${describeIslandElement(el)} deferred render failed: ${error?.message || error}`,
      );
      return null;
    })
    .finally(() => {
      if (timeoutId) window.clearTimeout(timeoutId);
      deferred.delete(el);
    });

  deferred.set(el, promise);
  return promise;
}

export function createDeferredIslandLoader(options = {}) {
  const scope = options.scope || document;
  const cleanups = new Set();

  const scan = (root = scope) => {
    deferredElements(root).forEach((el) => fetchDeferred(el));
  };

  const listen = (target, event, callback, listenerOptions) => {
    target.addEventListener(event, callback, listenerOptions);
    cleanups.add(() =>
      target.removeEventListener(event, callback, listenerOptions),
    );
  };

  const start = () => {
    const scanDocument = () => scan(document);

    if (document.readyState === "loading") {
      listen(document, "DOMContentLoaded", scanDocument, { once: true });
    } else {
      scanDocument();
    }

    listen(window, "phx:page-loading-stop", scanDocument);
  };

  const destroy = () => {
    cleanups.forEach((cleanup) => cleanup());
    cleanups.clear();
  };

  return { scan, start, destroy };
}

export function setupDeferredIslands(options = {}) {
  const loader = createDeferredIslandLoader(options);
  loader.start();
  return loader;
}
