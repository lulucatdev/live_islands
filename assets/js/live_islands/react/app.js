export const createReactIsland = ({ resolve }) => {
  return {
    resolve: async (name) => {
      let component = resolve(name);

      if (component instanceof Promise) {
        component = await component;
      }

      if (component && typeof component === "object") {
        component = component.default || component[name];
      }

      if (!component) {
        throw new Error(`Component "${name}" not found`);
      }

      return component;
    },
  };
};

export const normalizeReactIslandApp = (componentsOrApp) => {
  if (componentsOrApp && "resolve" in componentsOrApp) {
    return createReactIsland(componentsOrApp);
  }

  return createReactIsland({
    resolve: (name) => componentsOrApp[name],
  });
};
