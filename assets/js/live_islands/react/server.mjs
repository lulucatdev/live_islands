import React from "react";
import { renderToString } from "react-dom/server";
import { getComponentTree } from "./utils";
import { normalizeReactIslandApp } from "./app";

function getChildren(slots) {
  if (!slots?.default) {
    return [];
  }

  return [
    React.createElement("div", {
      dangerouslySetInnerHTML: { __html: slots.default.trim() },
    }),
  ];
}

export function getRender(components) {
  const app = normalizeReactIslandApp(components);

  return async function render(name, props, slots) {
    const Component = await app.resolve(name);
    const children = getChildren(slots);
    const tree = getComponentTree(Component, props, children);

    // https://react.dev/reference/react-dom/server/renderToString
    return renderToString(tree);
  };
}
