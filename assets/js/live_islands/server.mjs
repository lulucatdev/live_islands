export { getRender as getReactRender } from "./react/server.mjs";
export { getRender as getVueRender } from "./vue/server.ts";

export function getRender({ react, vue } = {}) {
  const renderReact = react?.render || react;
  const renderVue = vue?.render || vue;

  return function render(framework, name, props, slots) {
    if (framework === "react" && renderReact) {
      return renderReact(name, props, slots);
    }

    if (framework === "vue" && renderVue) {
      return renderVue(name, props, slots);
    }

    throw new Error(`No SSR renderer configured for ${framework}`);
  };
}
