import { getHooks as getReactHooks } from "./react/hooks.js";
import { getHooks as getVueHooks } from "./vue/index.js";
import { setupIslandPrefetch } from "./prefetch.js";

export { getReactHooks, getVueHooks };
export { defineClientStrategy } from "./hydration.js";
export {
  createIslandPrefetcher,
  definePrefetchStrategy,
  getIslandManifest,
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

export function getIslandHooks({
  react,
  vue,
  prefetch,
}: {
  react?: any;
  vue?: any;
  prefetch?: boolean | { defaultPolicy?: string };
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
    ...(react ? getReactHooks(react) : {}),
    ...(vue ? getVueHooks(vue) : {}),
  };
}
