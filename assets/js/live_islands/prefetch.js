import { describeIslandElement, warnLiveIslands } from "./diagnostics.js";
import { normalizeReactIslandApp } from "./react/app.js";
import { normalizeVueIslandApp } from "./vue/app.js";

const ISLAND_SELECTOR = "[data-framework][data-name]";
const PREFETCHED = new Set();

const onIdle = (callback) => {
  if ("requestIdleCallback" in window) {
    const id = window.requestIdleCallback(callback);
    return () => window.cancelIdleCallback(id);
  }

  const id = window.setTimeout(callback, 1);
  return () => window.clearTimeout(id);
};

const onVisible = (el, callback) => {
  if (!("IntersectionObserver" in window)) {
    callback();
    return () => {};
  }

  const observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) {
      observer.disconnect();
      callback();
    }
  });

  observer.observe(el);
  return () => observer.disconnect();
};

const onMedia = (query, callback) => {
  if (!query) return onIdle(callback);

  const media = window.matchMedia(query);
  if (media.matches) {
    callback();
    return () => {};
  }

  const listener = (event) => {
    if (event.matches) {
      media.removeEventListener("change", listener);
      callback();
    }
  };

  media.addEventListener("change", listener);
  return () => media.removeEventListener("change", listener);
};

const once = (el, events, callback) => {
  const done = () => {
    events.forEach((event) => el.removeEventListener(event, done));
    callback();
  };

  events.forEach((event) => el.addEventListener(event, done, { once: true }));
  return () => events.forEach((event) => el.removeEventListener(event, done));
};

const normalizePolicy = (policy, defaultPolicy = "none") => {
  switch (policy || defaultPolicy) {
    case true:
      return "visible";
    case false:
    case "false":
    case "none":
      return "none";
    case "eager":
    case "load":
      return "load";
    case "idle":
      return "idle";
    case "viewport":
    case "visible":
      return "visible";
    case "hover":
      return "hover";
    case "tap":
      return "tap";
    case "media":
      return "media";
    default:
      return "unknown";
  }
};

const islandElements = (root = document) => {
  const elements = [];

  if (root.matches?.(ISLAND_SELECTOR)) elements.push(root);
  if (root.querySelectorAll)
    elements.push(...root.querySelectorAll(ISLAND_SELECTOR));

  return elements;
};

const normalizeApp = (framework, app) => {
  if (!app) return null;
  return framework === "react"
    ? normalizeReactIslandApp(app)
    : normalizeVueIslandApp(app);
};

export function getIslandManifest(root = document) {
  const seen = new Set();

  return islandElements(root).flatMap((el) => {
    const framework = el.getAttribute("data-framework");
    const name = el.getAttribute("data-name");
    if (!framework || !name) return [];

    const key = `${framework}:${name}`;
    if (seen.has(key)) return [];
    seen.add(key);

    return [
      {
        framework,
        name,
        id: el.id || null,
        client: el.getAttribute("data-client") || "load",
        prefetch: el.getAttribute("data-prefetch") || "none",
        prefetchMedia:
          el.getAttribute("data-prefetch-media") ||
          el.getAttribute("data-client-media") ||
          null,
        ssr: el.getAttribute("data-ssr") === "true",
      },
    ];
  });
}

export function createIslandPrefetcher({ react, vue } = {}, options = {}) {
  const apps = {
    react: normalizeApp("react", react),
    vue: normalizeApp("vue", vue),
  };
  const defaultPolicy = options.defaultPolicy || "none";
  const scheduled = new WeakMap();
  const cleanups = new Set();

  const preload = (el) => {
    const framework = el.getAttribute("data-framework");
    const name = el.getAttribute("data-name");
    const app = apps[framework];

    if (!framework || !name || !app?.preload) return;

    const key = `${framework}:${name}`;
    if (PREFETCHED.has(key)) return;
    PREFETCHED.add(key);

    app.preload(name).catch((error) => {
      PREFETCHED.delete(key);
      warnLiveIslands(
        `${describeIslandElement(el)} prefetch failed: ${error?.message || error}`,
      );
    });
  };

  const schedule = (el) => {
    if (scheduled.has(el)) return;

    const policy = normalizePolicy(
      el.getAttribute("data-prefetch"),
      defaultPolicy,
    );
    let cancel;

    switch (policy) {
      case "none":
        cancel = () => {};
        break;
      case "load":
        preload(el);
        cancel = () => {};
        break;
      case "idle":
        cancel = onIdle(() => preload(el));
        break;
      case "visible":
        cancel = onVisible(el, () => preload(el));
        break;
      case "hover":
        cancel = once(el, ["pointerenter", "focusin"], () => preload(el));
        break;
      case "tap":
        cancel = once(el, ["pointerdown", "touchstart"], () => preload(el));
        break;
      case "media":
        cancel = onMedia(
          el.getAttribute("data-prefetch-media") ||
            el.getAttribute("data-client-media"),
          () => preload(el),
        );
        break;
      default:
        warnLiveIslands(
          `${describeIslandElement(el)} uses unknown prefetch policy "${el.getAttribute(
            "data-prefetch",
          )}".`,
        );
        cancel = () => {};
        break;
    }

    scheduled.set(el, cancel);
    cleanups.add(cancel);
  };

  const scan = (root = document) => {
    islandElements(root).forEach(schedule);
  };

  const listen = (event, callback) => {
    window.addEventListener(event, callback);
    cleanups.add(() => window.removeEventListener(event, callback));
  };

  const start = () => {
    const scanDocument = () => scan(document);

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", scanDocument, {
        once: true,
      });
      cleanups.add(() =>
        document.removeEventListener("DOMContentLoaded", scanDocument),
      );
    } else {
      scanDocument();
    }

    listen("phx:page-loading-stop", scanDocument);
    listen("live-islands:mounted", (event) =>
      scan(event.detail?.el || document),
    );
  };

  const destroy = () => {
    cleanups.forEach((cleanup) => cleanup());
    cleanups.clear();
  };

  return {
    manifest: getIslandManifest,
    scan,
    start,
    destroy,
  };
}

export function setupIslandPrefetch(apps, options = {}) {
  const controller = createIslandPrefetcher(apps, options);
  controller.start();
  return controller;
}
