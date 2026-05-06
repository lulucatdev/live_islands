const MAX_AVAILABLE = 12;

const compact = (value) => {
  if (!value) return value;
  return value
    .replace(/^\.\//, "")
    .replace(/\.(vue|jsx|tsx|js|ts)$/, "")
    .replace(/\/index$/, "");
};

export const availableComponentNames = (components) => {
  if (Array.isArray(components))
    return components.map(compact).filter(Boolean).sort();
  if (!components || typeof components !== "object") return [];

  return Object.keys(components).map(compact).filter(Boolean).sort();
};

export const availableSuffix = (available) => {
  if (!available || available.length === 0) return "";

  const visible = available.slice(0, MAX_AVAILABLE);
  const remaining = available.length - visible.length;
  const suffix = remaining > 0 ? `, and ${remaining} more` : "";

  return ` Available components: ${visible.join(", ")}${suffix}.`;
};

export const islandLabel = (framework, name) => {
  const component = name ? ` component "${name}"` : " component";
  return `[LiveIslands][${framework}]${component}`;
};

export const componentNotFoundError = (framework, name, available) =>
  new Error(
    `${islandLabel(framework, name)} was not found. Check the island name and component registry.${availableSuffix(available)}`,
  );

export const componentExportError = (framework, name, available) =>
  new Error(
    `${islandLabel(framework, name)} resolved to a module without a default export or a matching named export.${availableSuffix(available)}`,
  );

export const componentLoadError = (framework, name, error, available) => {
  const message = error?.message ? ` ${error.message}` : "";
  const wrapped = new Error(
    `${islandLabel(framework, name)} failed to load.${message}${availableSuffix(available)}`,
  );

  if (error) wrapped.cause = error;
  return wrapped;
};

export const describeIslandElement = (el) => {
  const framework = el?.getAttribute?.("data-framework") || "unknown";
  const name = el?.getAttribute?.("data-name") || "unknown";
  const id = el?.id ? `#${el.id}` : "";

  return `${framework}:${name}${id}`;
};

export const warnLiveIslands = (message) => {
  if (typeof console !== "undefined" && console.warn) {
    console.warn(`[LiveIslands] ${message}`);
  }
};
