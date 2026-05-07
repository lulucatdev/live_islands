// polyfill recommended by Vite https://vitejs.dev/config/build-options#build-modulepreload
import "vite/modulepreload-polyfill";

import { createReactIsland } from "live_islands/react/app";

const components = {
  BenchmarkDeferredReport: () => import("./benchmark-deferred-report"),
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
  TodoCommandCenter: () => import("./todo-command-center"),
  TodoDeferredDigest: () => import("./todo-digests"),
  TodoFocusTimer: () => import("./todo-focus-timer"),
  TodoSsrDigest: () => import("./todo-digests"),
  TodoWorkspace: () => import("./todo-workspace"),
  Typescript: () => import("./typescript"),
};

const componentPreloadUrls = {
  SimpleProps: () => urlsFromLoader(components.SimpleProps),
};

const urlsFromLoader = (loader) => {
  const match = loader?.toString().match(/import\(["'](.+?)["']\)/);
  return match ? [new URL(match[1], import.meta.url).href] : [];
};

export default createReactIsland({
  availableComponents: components,
  preloadUrls: (name) => componentPreloadUrls[name]?.() || [],
  resolve: (name) => {
    const component = components[name];
    return typeof component === "function" ? component() : component;
  },
});
