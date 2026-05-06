import { createReactIsland, Link } from "live_islands/react";

const components = {
  Simple: () => import("./simple"),
  LinkExample: () => import("./link-example"),
  Link,
};

export default createReactIsland({
  resolve: (name) => {
    const component = components[name];
    return typeof component === "function" && name !== "Link"
      ? component()
      : component;
  },
});
