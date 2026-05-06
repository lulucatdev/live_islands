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

export function scheduleHydration(el, callback) {
  const strategy = el.getAttribute("data-client") || "load";
  let cancelled = false;

  const hydrate = () => {
    if (!cancelled) runAsync(callback);
  };

  let cancel;
  switch (strategy) {
    case "none":
      cancel = () => {};
      break;
    case "idle":
      cancel = onIdle(hydrate);
      break;
    case "visible":
      cancel = onVisible(el, hydrate);
      break;
    case "media":
      cancel = onMedia(el.getAttribute("data-client-media"), hydrate);
      break;
    case "load":
    default:
      hydrate();
      cancel = () => {};
      break;
  }

  return () => {
    cancelled = true;
    cancel();
  };
}
