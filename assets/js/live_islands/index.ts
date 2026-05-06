import { getHooks as getReactHooks } from "./react/hooks.js";
import { getHooks as getVueHooks } from "./vue/index.js";

export { getReactHooks, getVueHooks };
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
}: { react?: any; vue?: any } = {}) {
  return {
    ...(react ? getReactHooks(react) : {}),
    ...(vue ? getVueHooks(vue) : {}),
  };
}
