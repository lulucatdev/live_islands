import { createApp, createSSRApp, reactive, type App } from "vue";
import { normalizeVueIslandApp } from "./app.js";
import type {
  ComponentMap,
  VueIslandApp,
  VueIslandOptions,
  LiveHook,
  Hook,
} from "./types.js";
import { vueIslandInjectKey, hooksById } from "./use.js";
import { getProps, getDiff, getElementId } from "./attrs.js";
import { applyPatch } from "./jsonPatch.js";
import { registerInjector, unregisterInjector, syncSlots } from "./inject.js";
import { scheduleHydration } from "../hydration.js";
import { describeIslandElement } from "../diagnostics.js";

const shouldHydrate = (el: HTMLElement): boolean =>
  el.getAttribute("data-ssr") === "true" && el.hasChildNodes();

export const getVueIslandHook = ({ resolve, setup }: VueIslandApp): Hook => ({
  mounted() {
    const el = this.el as HTMLElement;
    const componentName = el.getAttribute("data-name");
    if (!componentName) {
      throw new Error(
        `[LiveIslands][vue] Component name must be provided for ${describeIslandElement(el)}.`,
      );
    }

    const props = reactive(getProps(el, this.liveSocket));
    applyPatch(props, getDiff(el, "data-streams-diff"));

    this.vue = { props, slots: reactive({}), app: null };
    const elementId = getElementId(el);
    if (elementId) hooksById.set(elementId, this as LiveHook);
    syncSlots(elementId);

    this.vue.cancelHydration = scheduleHydration(el, async () => {
      const component = await resolve(componentName);

      const targetId = el.getAttribute("data-inject");
      if (targetId && elementId && component) {
        const slotName = el.getAttribute("data-inject-slot") || "default";
        registerInjector(elementId, targetId, slotName, component);
        return;
      }

      if (!component) return;
      const makeApp = shouldHydrate(el) ? createSSRApp : createApp;

      const app = setup({
        createApp: makeApp,
        component,
        props,
        slots: this.vue.slots,
        plugin: {
          install: (app: App) => {
            app.provide(vueIslandInjectKey, this as LiveHook);
            app.config.globalProperties.$live = this as LiveHook;
          },
        },
        el: this.el,
        ssr: false,
      });

      if (!app) throw new Error("Setup function did not return a Vue app!");

      this.vue.app = app;
    });
  },
  updated() {
    if (this.el.getAttribute("data-use-diff") === "true") {
      applyPatch(this.vue.props, getDiff(this.el, "data-props-diff"));
    } else {
      Object.assign(this.vue.props, getProps(this.el, this.liveSocket));
    }
    applyPatch(this.vue.props, getDiff(this.el, "data-streams-diff"));
    syncSlots(getElementId(this.el as HTMLElement));
  },
  reconnected() {
    Object.assign(this.vue.props, getProps(this.el, this.liveSocket));
    applyPatch(this.vue.props, getDiff(this.el, "data-streams-diff"));
    syncSlots(getElementId(this.el as HTMLElement));
  },
  destroyed() {
    const elementId = getElementId(this.el as HTMLElement);
    if (elementId) {
      unregisterInjector(elementId);
      hooksById.delete(elementId);
    }

    const instance = this.vue.app;
    if (this.vue.cancelHydration) this.vue.cancelHydration();

    if (instance) {
      window.addEventListener(
        "phx:page-loading-stop",
        () => instance.unmount(),
        { once: true },
      );
    }
  },
});

/**
 * Returns the hooks for the LiveIslands Vue app.
 * @param components - The components to use in the app.
 * @param options - The options for the LiveIslands Vue app.
 * @returns The hooks for the LiveIslands Vue app.
 */
type VueIslandHooks = { LiveIslandsVueHook: Hook };
type getHooksAppFn = (app: VueIslandApp | VueIslandOptions) => VueIslandHooks;
type getHooksComponentsOptions = { initializeApp?: VueIslandOptions["setup"] };
type getHooksComponentsFn = (
  components: ComponentMap,
  options?: getHooksComponentsOptions,
) => VueIslandHooks;

export const getHooks: getHooksComponentsFn | getHooksAppFn = (
  componentsOrApp: ComponentMap | VueIslandApp,
  options?: getHooksComponentsOptions,
) => {
  const app = normalizeVueIslandApp(componentsOrApp, options ?? {});
  return { LiveIslandsVueHook: getVueIslandHook(app) };
};
