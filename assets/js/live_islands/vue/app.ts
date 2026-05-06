import { type App, type Component, h } from "vue";
import type {
  ComponentOrComponentPromise,
  SetupContext,
  VueIslandOptions,
  ComponentMap,
  VueIslandApp,
} from "./types.js";
import {
  availableComponentNames,
  componentLoadError,
  componentNotFoundError,
} from "../diagnostics.js";

/**
 * Initializes a Vue app with the given options and mounts it to the specified element.
 * It's a default implementation of the `setup` option, which can be overridden.
 * If you want to override it, simply provide your own implementation of the `setup` option.
 */
export const defaultSetup = ({
  createApp,
  component,
  props,
  slots,
  plugin,
  el,
}: SetupContext) => {
  const app = createApp({ render: () => h(component, props, slots) });
  app.use(plugin);
  app.mount(el);
  return app;
};

export const normalizeVueIslandApp = (
  components: ComponentMap | VueIslandOptions | VueIslandApp,
  options: { initializeApp?: (context: SetupContext) => App } = {},
): VueIslandApp => {
  if ("resolve" in components) {
    return createVueIsland(components as VueIslandOptions);
  } else {
    return createVueIsland({
      resolve: (name: string) => {
        for (const [key, value] of Object.entries(components)) {
          if (
            key.endsWith(`${name}.vue`) ||
            key.endsWith(`${name}/index.vue`)
          ) {
            return value;
          }
        }
      },
      setup: options.initializeApp,
      availableComponents: components,
    });
  }
};

const resolveComponent = async (
  component: ComponentOrComponentPromise,
): Promise<Component> => {
  if (typeof component === "function") {
    // it's an async component, let's try to load it
    component = await (
      component as () => Promise<ComponentOrComponentPromise>
    )();
  } else if (component instanceof Promise) {
    component = await component;
  }

  if (component && "default" in component) {
    // if there's a default export, use it
    component = component.default;
  }

  return component;
};

export const createVueIsland = ({
  resolve,
  setup,
  availableComponents,
}: VueIslandOptions) => {
  if (typeof resolve !== "function") {
    throw new Error(
      "[LiveIslands][vue] createVueIsland requires a resolve function.",
    );
  }

  const available = availableComponentNames(availableComponents);
  const resolved = new Map<string, Promise<Component>>();

  const load = async (path: string): Promise<Component> => {
    if (resolved.has(path)) return resolved.get(path) as Promise<Component>;

    const promise = (async () => {
      let component: ComponentOrComponentPromise | undefined | null;

      try {
        component = resolve(path);
      } catch (error) {
        throw componentLoadError("vue", path, error, available);
      }

      if (!component) throw componentNotFoundError("vue", path, available);

      try {
        return await resolveComponent(component);
      } catch (error) {
        throw componentLoadError("vue", path, error, available);
      }
    })();

    resolved.set(path, promise);

    try {
      return await promise;
    } catch (error) {
      resolved.delete(path);
      throw error;
    }
  };

  return {
    setup: setup || defaultSetup,
    resolve: load,
    preload: load,
  };
};
