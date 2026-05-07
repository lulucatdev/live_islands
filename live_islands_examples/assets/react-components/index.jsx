// polyfill recommended by Vite https://vitejs.dev/config/build-options#build-modulepreload
import "vite/modulepreload-polyfill";

import { createReactIsland } from "live_islands/react/app";

const components = {
  BenchmarkStaticReport: () => import("./benchmark-static-report"),
  BenchmarkSummary: () => import("./benchmark-summary"),
  BenchmarkWorkbench: () => import("./benchmark-workbench"),
  Capabilities: () => import("./capabilities"),
  Context: () => import("./context"),
  Counter: () => import("./counter"),
  DelaySlider: () => import("./delay-slider"),
  FlashSonner: () => import("./flash-sonner"),
  GithubCode: () => import("./github-code"),
  Lazy: () => import("./lazy"),
  Link: () => import("./link"),
  LinkExample: () => import("./link-example"),
  LogList: () => import("./log-list"),
  SSR: () => import("./ssr"),
  Simple: () => import("./simple"),
  SimpleProps: () => import("./simple-props"),
  Slot: () => import("./slot"),
  Typescript: () => import("./typescript"),
};

export default createReactIsland({
  availableComponents: components,
  resolve: (name) => {
    const component = components[name];
    return typeof component === "function" ? component() : component;
  },
});
