import reactComponents from "../react-components";
import vueComponents from "../vue-components";
import { getRender as getReactRender } from "live_islands/react/server";
import { getRender as getVueRender } from "live_islands/vue/server";

const renderReact = getReactRender(reactComponents);
const renderVue = getVueRender(vueComponents);

export function render(framework, name, props, slots) {
  switch (framework) {
    case "react":
      return renderReact(name, props, slots);
    case "vue":
      return renderVue(name, props, slots);
    default:
      throw new Error(`Unsupported SSR framework: ${framework}`);
  }
}
