// polyfill recommended by Vite https://vitejs.dev/config/build-options#build-modulepreload
import "vite/modulepreload-polyfill";

import { createReactIsland, Link } from "live_islands/react";

const components = {
  Capabilities: () => import("./capabilities"),
  Context: () => import("./context"),
  Counter: () => import("./counter"),
  DelaySlider: () => import("./delay-slider"),
  FlashSonner: () => import("./flash-sonner"),
  GithubCode: () => import("./github-code"),
  Lazy: () => import("./lazy"),
  Link,
  LinkExample: () => import("./link-example"),
  LogList: () => import("./log-list"),
  SSR: () => import("./ssr"),
  Simple: () => import("./simple"),
  SimpleProps: () => import("./simple-props"),
  Slot: () => import("./slot"),
  Typescript: () => import("./typescript"),
};

export default createReactIsland({
  resolve: (name) => {
    const component = components[name];
    return typeof component === "function" && name !== "Link"
      ? component()
      : component;
  },
});
