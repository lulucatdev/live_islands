import { getHooks as getReactHooks } from "./react/index.mjs";
import { getHooks as getVueHooks } from "./vue/index.ts";

export { getReactHooks };
export { getHooks } from "./react/index.mjs";
export { Link } from "./react/link.jsx";
export {
  LiveFormProvider,
  useArrayField,
  useEventReply,
  useField,
  useLiveConnection,
  useLiveEvent,
  useLiveForm,
  useLiveNavigation,
  useLiveReact,
  useLiveUpload,
} from "./react/context.jsx";

export {
  createLiveVue,
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
  useLiveVue,
} from "./vue/index.ts";
export { getVueHooks };

export function getIslandHooks({ react, vue } = {}) {
  return {
    ...(react ? getReactHooks(react) : {}),
    ...(vue ? getVueHooks(vue) : {}),
  };
}
