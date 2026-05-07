import { setupIslandPrefetch } from "./prefetch.js";

export { defineClientStrategy } from "./hydration.js";
export {
  createIslandPrefetcher,
  definePrefetchStrategy,
  getIslandManifest,
  getIslandScope,
  getPageIslandManifest,
  setupIslandPrefetch,
} from "./prefetch.js";
export { createReactIsland } from "./react/app.js";
export { Link as ReactLink } from "./react/link.jsx";
export {
  LiveFormProvider,
  useArrayField,
  useEventReply,
  useField,
  useLiveConnection,
  useLiveEvent,
  useLiveForm,
  useLiveNavigation,
  useLiveUpload,
  useReactIsland,
} from "./react/context.jsx";

export {
  createVueIsland,
  findComponent,
  Link as VueLink,
  useArrayField as useVueArrayField,
  useEventReply as useVueEventReply,
  useField as useVueField,
  useLiveConnection as useVueLiveConnection,
  useLiveEvent as useVueLiveEvent,
  useLiveForm as useVueLiveForm,
  useLiveNavigation as useVueLiveNavigation,
  useLiveUpload as useVueLiveUpload,
  useVueIsland,
} from "./vue/index.js";

type HookMap = Record<string, Record<string, Function>>;
type HookLoader = () => Promise<Record<string, Function>>;

function lazyHook(loader: HookLoader): Record<string, Function> {
  let loadedHook: Record<string, Function> | null = null;
  let hookPromise: Promise<Record<string, Function>> | null = null;

  const load = () => {
    hookPromise ||= loader().then((hook) => {
      loadedHook = hook;
      return hook;
    });

    return hookPromise;
  };

  const report = (error: unknown) => {
    setTimeout(() => {
      throw error;
    });
  };

  const installHookHelpers = (
    instance: any,
    hook: Record<string, Function>,
  ) => {
    for (const [key, value] of Object.entries(hook)) {
      if (!["mounted", "updated", "reconnected", "destroyed"].includes(key)) {
        instance[key] = value;
      }
    }
  };

  const callOrQueue = (instance: any, lifecycle: string) => {
    if (loadedHook) {
      installHookHelpers(instance, loadedHook);
      return loadedHook[lifecycle]?.call(instance);
    }

    instance.__liveIslandsPendingLifecycles ||= [];
    instance.__liveIslandsPendingLifecycles.push(lifecycle);
    load().catch(report);
  };

  return {
    mounted(this: any) {
      this.__liveIslandsPendingLifecycles = [];

      if (loadedHook) {
        installHookHelpers(this, loadedHook);
        loadedHook.mounted?.call(this);
        return;
      }

      load()
        .then((hook) => {
          if (this.__liveIslandsDestroyed) return;

          installHookHelpers(this, hook);
          hook.mounted?.call(this);

          for (const lifecycle of this.__liveIslandsPendingLifecycles.splice(
            0,
          )) {
            hook[lifecycle]?.call(this);
          }
        })
        .catch(report);
    },
    updated(this: any) {
      callOrQueue(this, "updated");
    },
    reconnected(this: any) {
      callOrQueue(this, "reconnected");
    },
    destroyed(this: any) {
      this.__liveIslandsDestroyed = true;
      if (loadedHook) return loadedHook.destroyed?.call(this);
    },
  };
}

async function loadReactHook(react: any) {
  const { getHooks } = await import("./react/hooks.js");
  return getHooks(react).LiveIslandsReactHook;
}

async function loadVueHook(vue: any) {
  const { getHooks } = await import("./vue/hooks.js");
  return getHooks(vue).LiveIslandsVueHook;
}

export function getIslandHooks({
  react,
  vue,
  prefetch,
}: {
  react?: any;
  vue?: any;
  prefetch?:
    | boolean
    | {
        defaultPolicy?: string;
        scope?: "page" | "document" | string | Element;
      };
} = {}) {
  if (prefetch && typeof window !== "undefined") {
    const current = (window as any).__liveIslandsPrefetch;
    if (current?.destroy) current.destroy();

    (window as any).__liveIslandsPrefetch = setupIslandPrefetch(
      { react, vue },
      prefetch === true ? {} : prefetch,
    );
  }

  return {
    ...(react
      ? ({
          LiveIslandsReactHook: lazyHook(() => loadReactHook(react)),
        } as HookMap)
      : {}),
    ...(vue
      ? ({ LiveIslandsVueHook: lazyHook(() => loadVueHook(vue)) } as HookMap)
      : {}),
  } as HookMap;
}
