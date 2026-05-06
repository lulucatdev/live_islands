import { describeIslandElement, warnLiveIslands } from "./diagnostics.js";

const runAsync = (callback) => {
  Promise.resolve()
    .then(callback)
    .catch((error) => {
      setTimeout(() => {
        throw error;
      });
    });
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

const onInteraction = (el, callback) => {
  const events = ["pointerenter", "pointerdown", "focusin", "touchstart"];

  const done = () => {
    events.forEach((event) => el.removeEventListener(event, done));
    callback();
  };

  events.forEach((event) => el.addEventListener(event, done, { once: true }));
  return () => events.forEach((event) => el.removeEventListener(event, done));
};

const clientStrategies = new Map([
  ["none", () => () => {}],
  ["idle", (_el, hydrate) => onIdle(hydrate)],
  ["visible", (el, hydrate) => onVisible(el, hydrate)],
  [
    "media",
    (el, hydrate) => {
      if (!el.getAttribute("data-client-media")) {
        warnLiveIslands(
          `${describeIslandElement(el)} uses client="media" without data-client-media. Hydrating on idle instead.`,
        );
      }

      return onMedia(el.getAttribute("data-client-media"), hydrate);
    },
  ],
  ["interaction", (el, hydrate) => onInteraction(el, hydrate)],
  [
    "load",
    (_el, hydrate) => {
      hydrate();
      return () => {};
    },
  ],
]);

export function defineClientStrategy(name, schedule) {
  if (!name || typeof schedule !== "function") {
    throw new Error(
      "[LiveIslands] defineClientStrategy requires a name and scheduler function.",
    );
  }

  clientStrategies.set(name, schedule);
}

export function scheduleHydration(el, callback) {
  const strategy = el.getAttribute("data-client") || "load";
  let cancelled = false;

  const hydrate = () => {
    if (!cancelled) runAsync(callback);
  };

  const scheduler = clientStrategies.get(strategy);
  let cancel = () => {};

  if (scheduler) {
    cancel = scheduler(el, hydrate) || cancel;
  } else {
    warnLiveIslands(
      `${describeIslandElement(el)} uses unknown client strategy "${strategy}". Falling back to "load".`,
    );
    clientStrategies.get("load")(el, hydrate);
  }

  return () => {
    cancelled = true;
    cancel();
  };
}
