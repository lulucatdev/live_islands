import components from "../react-components";
import { getRender } from "live_islands/react/server";

const renderReact = getRender(components);

export function render(framework, name, props, slots) {
  if (framework !== "react") {
    throw new Error(`Unsupported SSR framework: ${framework}`);
  }

  return renderReact(name, props, slots);
}
