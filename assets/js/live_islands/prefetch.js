import { describeIslandElement, warnLiveIslands } from "./diagnostics.js";

const ISLAND_SELECTOR = "[data-framework][data-name]";
const PAGE_SCOPE_SELECTOR = "[data-live-islands-page], [data-phx-main]";
const PREFETCHED = new Set();
const MODULE_PRELOADED = new Set();
const PREFETCH_PRIORITY = {
  low: 0,
  normal: 1,
  high: 2,
};

const dispatchPrefetch = (name, el, detail = {}) => {
  window.dispatchEvent(
    new CustomEvent(`live-islands:prefetch:${name}`, {
      detail: { el, ...detail },
    }),
  );
};

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

const onEvents = (el, events, callback) => {
  const done = (event) => {
    events.forEach((event) => el.removeEventListener(event, done));
    callback(event);
  };

  events.forEach((event) => el.addEventListener(event, done, { once: true }));
  return () => events.forEach((event) => el.removeEventListener(event, done));
};

const connectionInfo = () => {
  const connection =
    navigator.connection ||
    navigator.mozConnection ||
    navigator.webkitConnection ||
    {};

  return {
    saveData: Boolean(connection.saveData),
    effectiveType: connection.effectiveType || null,
  };
};

const softPrefetchBlocked = (options = {}) => {
  if (options.networkAware === false) return null;

  const connection = connectionInfo();
  if (options.respectSaveData !== false && connection.saveData) {
    return "save-data";
  }

  const effectiveType = String(connection.effectiveType || "");
  if (/^(slow-)?2g$/i.test(effectiveType)) {
    return `effective-type:${effectiveType}`;
  }

  return null;
};

const onIntent = (el, preload, context = {}) => {
  let idleCleanup = () => {};

  const visibleCleanup = onVisible(el, () => {
    const reason = softPrefetchBlocked(context.options);
    if (reason) {
      dispatchPrefetch("skip", el, {
        framework: el.getAttribute("data-framework"),
        name: el.getAttribute("data-name"),
        policy: "intent",
        trigger: "visible",
        priority: "low",
        reason,
      });
      return;
    }

    idleCleanup = onIdle(() =>
      preload(el, {
        policy: "intent",
        trigger: "visible",
        priority: "low",
      }),
    );
  });

  const intentCleanup = onEvents(
    el,
    ["pointerenter", "focusin", "pointerdown", "touchstart"],
    (event) =>
      preload(el, {
        policy: "intent",
        trigger: event?.type || "intent",
        priority: "high",
      }),
  );

  return () => {
    idleCleanup();
    visibleCleanup();
    intentCleanup();
  };
};

const prefetchStrategies = new Map([
  ["none", () => () => {}],
  [
    "load",
    (el, preload) => {
      preload(el);
      return () => {};
    },
  ],
  ["idle", (el, preload) => onIdle(() => preload(el))],
  ["visible", (el, preload) => onVisible(el, () => preload(el))],
  [
    "hover",
    (el, preload) =>
      onEvents(el, ["pointerenter", "focusin"], () => preload(el)),
  ],
  [
    "tap",
    (el, preload) =>
      onEvents(el, ["pointerdown", "touchstart"], () => preload(el)),
  ],
  [
    "interaction",
    (el, preload) =>
      onEvents(
        el,
        ["pointerenter", "pointerdown", "focusin", "touchstart"],
        (event) => preload(el, { trigger: event?.type || "interaction" }),
      ),
  ],
  ["intent", onIntent],
  [
    "media",
    (el, preload) =>
      onMedia(
        el.getAttribute("data-prefetch-media") ||
          el.getAttribute("data-client-media"),
        () => preload(el),
      ),
  ],
]);

export function definePrefetchStrategy(name, schedule) {
  if (!name || typeof schedule !== "function") {
    throw new Error(
      "[LiveIslands] definePrefetchStrategy requires a name and scheduler function.",
    );
  }

  prefetchStrategies.set(name, schedule);
}

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
    case "interaction":
      return "interaction";
    case "intent":
      return "intent";
    case "media":
      return "media";
    default:
      return policy || defaultPolicy;
  }
};

const truthyAttr = (el, name) => {
  const value = el.getAttribute(name);
  return value != null && value !== "false";
};

const islandElements = (root = document) => {
  const elements = [];

  if (root.matches?.(ISLAND_SELECTOR)) elements.push(root);
  if (root.querySelectorAll)
    elements.push(...root.querySelectorAll(ISLAND_SELECTOR));

  return elements;
};

const isDomRoot = (value) =>
  value &&
  (typeof value.querySelectorAll === "function" ||
    typeof value.matches === "function" ||
    value.nodeType === 9);

const documentFor = (root) =>
  root?.nodeType === 9 ? root : root?.ownerDocument || document;

const normalizeManifestArgs = (rootOrOptions, maybeOptions) => {
  if (isDomRoot(rootOrOptions) || rootOrOptions == null) {
    return {
      root: rootOrOptions || document,
      options: maybeOptions || {},
    };
  }

  return {
    root: document,
    options: rootOrOptions || {},
  };
};

const findPageScopeRoot = (root = document) => {
  const doc = documentFor(root);

  if (root.matches?.(PAGE_SCOPE_SELECTOR)) return root;

  const closest = root.closest?.(PAGE_SCOPE_SELECTOR);
  if (closest) return closest;

  return doc.querySelector(PAGE_SCOPE_SELECTOR) || root;
};

const resolveScopeRoot = (root = document, scope = "page") => {
  if (!scope || scope === "document") return root;
  if (scope === "page") return findPageScopeRoot(root);
  if (isDomRoot(scope)) return scope;

  if (typeof scope === "string") {
    return documentFor(root).querySelector(scope) || root;
  }

  return root;
};

export function getIslandScope(root = document, options = {}) {
  const scope = options.scope || "page";
  const scopeRoot = resolveScopeRoot(root, scope);
  const doc = documentFor(scopeRoot);
  const location = doc.defaultView?.location;

  return {
    root: scopeRoot,
    type: scope,
    page:
      scopeRoot.getAttribute?.("data-live-islands-page") ||
      (location ? `${location.pathname}${location.search}` : "document"),
    id: scopeRoot.id || null,
  };
}

const resolveFromComponentMap = (framework, components, name) => {
  if (framework === "vue") {
    return Object.entries(components).find(
      ([key]) =>
        key.endsWith(`${name}.vue`) || key.endsWith(`${name}/index.vue`),
    )?.[1];
  }

  return components[name];
};

const preloadValue = async (value) => {
  if (!value) return null;
  if (value instanceof Promise) return value;

  // import.meta.glob entries are zero-argument functions that return promises.
  // Direct component functions are already loaded and have nothing to preload.
  if (typeof value === "function" && value.length === 0) {
    const resolved = value();
    if (resolved instanceof Promise) return resolved;
  }

  return value;
};

const preloadModuleUrls = async (urls) => {
  const resolvedUrls = urls instanceof Promise ? await urls : urls;
  if (!Array.isArray(resolvedUrls)) return [];

  const inserted = [];
  for (const url of resolvedUrls) {
    if (!url || MODULE_PRELOADED.has(url)) continue;
    MODULE_PRELOADED.add(url);

    const link = document.createElement("link");
    link.rel = "modulepreload";
    link.href = url;
    document.head.appendChild(link);
    inserted.push(link.href);
  }

  return inserted;
};

const normalizePreloadApp = (framework, app) => {
  if (!app) return null;
  if (typeof app.preload === "function") return app;

  if (typeof app.resolve === "function") {
    return {
      preload: (name) => preloadValue(app.resolve(name)),
      preloadUrls: app.preloadUrls,
    };
  }

  return {
    preload: (name) =>
      preloadValue(resolveFromComponentMap(framework, app, name)),
  };
};

export function getIslandManifest(rootOrOptions = document, maybeOptions = {}) {
  const { root, options } = normalizeManifestArgs(rootOrOptions, maybeOptions);
  const scope = getIslandScope(root, options);
  const seen = new Set();

  return islandElements(scope.root).flatMap((el) => {
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
        page: scope.page,
        scopeId: scope.id,
        client: el.getAttribute("data-client") || "load",
        prefetch: el.getAttribute("data-prefetch") || "none",
        prefetchMedia:
          el.getAttribute("data-prefetch-media") ||
          el.getAttribute("data-client-media") ||
          null,
        ssr: el.getAttribute("data-ssr") === "true",
        serverOnly: truthyAttr(el, "data-server-only"),
        deferred: truthyAttr(el, "data-deferred"),
      },
    ];
  });
}

export function getPageIslandManifest(root = document) {
  return getIslandManifest(root, { scope: "page" });
}

export function createIslandPrefetcher({ react, vue } = {}, options = {}) {
  const apps = {
    react: normalizePreloadApp("react", react),
    vue: normalizePreloadApp("vue", vue),
  };
  const defaultPolicy = options.defaultPolicy || "none";
  const maxConcurrent = Math.max(1, Number(options.maxConcurrent || 2));
  const scope = options.scope || "page";
  const scheduled = new WeakMap();
  const cleanups = new Set();
  const queue = [];
  const queued = new Map();
  let active = 0;

  const priorityValue = (priority) =>
    PREFETCH_PRIORITY[priority] ?? PREFETCH_PRIORITY.normal;

  const normalizePriority = (priority, policy) => {
    if (Object.hasOwn(PREFETCH_PRIORITY, priority)) return priority;
    if (policy === "load" || policy === "intent") return "high";
    if (policy === "idle" || policy === "visible") return "low";
    return "normal";
  };

  const runQueue = () => {
    queue.sort((left, right) => right.priorityValue - left.priorityValue);

    while (active < maxConcurrent && queue.length > 0) {
      const job = queue.shift();
      const startedAt = performance.now();
      active += 1;
      queued.delete(job.key);
      dispatchPrefetch("start", job.el, {
        framework: job.framework,
        name: job.name,
        policy: job.policy,
        trigger: job.trigger,
        priority: job.priority,
      });

      let modulepreloadUrls = [];
      Promise.resolve()
        .then(() => preloadModuleUrls(job.app.preloadUrls?.(job.name)))
        .then((urls) => {
          modulepreloadUrls = urls;
          if (urls.length > 0) {
            dispatchPrefetch("modulepreload", job.el, {
              framework: job.framework,
              name: job.name,
              policy: job.policy,
              trigger: job.trigger,
              priority: job.priority,
              urls,
              count: urls.length,
            });
          }
        })
        .then(() => job.app.preload(job.name))
        .then(() =>
          dispatchPrefetch("load", job.el, {
            framework: job.framework,
            name: job.name,
            policy: job.policy,
            trigger: job.trigger,
            priority: job.priority,
            modulepreloadCount: modulepreloadUrls.length,
            modulepreloadUrls,
            duration: Math.round(performance.now() - startedAt),
          }),
        )
        .catch((error) => {
          PREFETCHED.delete(job.key);
          dispatchPrefetch("error", job.el, {
            framework: job.framework,
            name: job.name,
            policy: job.policy,
            trigger: job.trigger,
            priority: job.priority,
            message: error?.message || String(error),
            duration: Math.round(performance.now() - startedAt),
          });
          warnLiveIslands(
            `${describeIslandElement(job.el)} prefetch failed: ${error?.message || error}`,
          );
        })
        .finally(() => {
          active -= 1;
          runQueue();
        });
    }
  };

  const preload = (el, metadata = {}) => {
    const framework = el.getAttribute("data-framework");
    const name = el.getAttribute("data-name");
    const app = apps[framework];

    if (!framework || !name || !app?.preload) return;

    const key = `${framework}:${name}`;
    const policy =
      metadata.policy ||
      normalizePolicy(el.getAttribute("data-prefetch"), defaultPolicy);
    const trigger = metadata.trigger || policy;
    const priority = normalizePriority(metadata.priority, policy);
    const priorityWeight = priorityValue(priority);

    if (PREFETCHED.has(key)) {
      const job = queued.get(key);
      if (job && priorityWeight > job.priorityValue) {
        job.policy = policy;
        job.trigger = trigger;
        job.priority = priority;
        job.priorityValue = priorityWeight;
        dispatchPrefetch("queue", el, {
          framework,
          name,
          policy,
          trigger,
          priority,
          depth: queue.length,
          reprioritized: true,
        });
        runQueue();
      }
      return;
    }
    PREFETCHED.add(key);

    const job = {
      app,
      el,
      framework,
      key,
      name,
      policy,
      trigger,
      priority,
      priorityValue: priorityWeight,
    };
    queue.push(job);
    queued.set(key, job);
    dispatchPrefetch("queue", el, {
      framework,
      name,
      policy,
      trigger,
      priority,
      depth: queue.length,
    });
    runQueue();
  };

  const schedule = (el) => {
    if (scheduled.has(el)) return;

    const policy = normalizePolicy(
      el.getAttribute("data-prefetch"),
      defaultPolicy,
    );
    const scheduler = prefetchStrategies.get(policy);
    let cancel = () => {};

    if (scheduler) {
      cancel = scheduler(el, preload, { options, policy }) || cancel;
    } else {
      warnLiveIslands(
        `${describeIslandElement(el)} uses unknown prefetch policy "${el.getAttribute(
          "data-prefetch",
        )}".`,
      );
    }

    scheduled.set(el, cancel);
    cleanups.add(cancel);
  };

  const scan = (root = document) => {
    islandElements(resolveScopeRoot(root, scope)).forEach(schedule);
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
    listen("live-islands:deferred:load", (event) =>
      scan(event.detail?.el || document),
    );
  };

  const destroy = () => {
    cleanups.forEach((cleanup) => cleanup());
    cleanups.clear();
  };

  return {
    manifest: (root = document, manifestOptions = {}) =>
      getIslandManifest(root, { scope, ...manifestOptions }),
    pageManifest: getPageIslandManifest,
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
