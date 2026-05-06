// Used by the node.js worker for server-side rendering
import { getRender } from "live_islands/react/server";
import components from "../react-components";

const renderReact = getRender(components);

export function render(framework, name, props, slots) {
  if (framework !== "react") {
    throw new Error(`Unsupported SSR framework: ${framework}`);
  }

  return renderReact(name, props, slots);
}
