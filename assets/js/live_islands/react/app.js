import {
  availableComponentNames,
  componentExportError,
  componentLoadError,
  componentNotFoundError,
} from "../diagnostics.js";

export const createReactIsland = ({ resolve, availableComponents }) => {
  if (typeof resolve !== "function") {
    throw new Error(
      "[LiveIslands][react] createReactIsland requires a resolve function.",
    );
  }

  const available = availableComponentNames(
    availableComponents || resolve.availableComponents,
  );

  return {
    resolve: async (name) => {
      let component;

      try {
        component = resolve(name);

        if (component instanceof Promise) {
          component = await component;
        }
      } catch (error) {
        throw componentLoadError("react", name, error, available);
      }

      if (
        component &&
        typeof component === "object" &&
        (component[Symbol.toStringTag] === "Module" ||
          "default" in component ||
          name in component)
      ) {
        if ("default" in component || name in component) {
          component = component.default || component[name];
        } else {
          throw componentExportError("react", name, available);
        }
      }

      if (!component) {
        throw componentNotFoundError("react", name, available);
      }

      return component;
    },
  };
};

export const normalizeReactIslandApp = (componentsOrApp) => {
  if (componentsOrApp && "resolve" in componentsOrApp) {
    return createReactIsland(componentsOrApp);
  }

  const components = componentsOrApp || {};

  return createReactIsland({
    resolve: Object.assign((name) => components[name], {
      availableComponents: components,
    }),
  });
};
