import type { App, Component, createApp, createSSRApp, h, Plugin } from "vue";
import type {
  LiveSocketInstanceInterface,
  ViewHook,
  Hook,
} from "./phoenixFallbackTypes";
export type { LiveSocketInstanceInterface, ViewHook, Hook };

export type ComponentOrComponentModule = Component | { default: Component };
export type ComponentOrComponentPromise =
  | ComponentOrComponentModule
  | Promise<ComponentOrComponentModule>;
export type ComponentMap = Record<string, ComponentOrComponentPromise>;

export type VueComponent = ComponentOrComponentPromise;

type VueComponentInternal = Parameters<typeof h>[0];
type VuePropsInternal = Parameters<typeof h>[1];
type VueSlotsInternal = Parameters<typeof h>[2];

export type VueArgs = {
  props: VuePropsInternal;
  slots: VueSlotsInternal;
  app: App<Element>;
  cancelHydration?: () => void;
};

// all the functions and additional properties that are available on the LiveHook
// We use a mapped type to extract only public members from ViewHook (stripping private fields),
// and omit lifecycle methods (required on ViewHook but optional on HookInterface where `this` lives)
type ViewHookLifecycle =
  | "mounted"
  | "beforeUpdate"
  | "updated"
  | "destroyed"
  | "disconnected"
  | "reconnected";
export type LiveHook = Omit<
  { [K in keyof ViewHook]: ViewHook[K] },
  ViewHookLifecycle
> & { vue: VueArgs; liveSocket: LiveSocketInstanceInterface };

// Phoenix LiveView Upload types for client-side use
export interface UploadEntry {
  ref: string;
  client_name: string;
  client_size: number;
  client_type: string;
  progress: number;
  done: boolean;
  valid: boolean;
  preflighted: boolean;
  errors: string[];
}

export interface UploadConfig {
  ref: string;
  name: string;
  accept: string | false;
  max_entries: number;
  auto_upload: boolean;
  entries: UploadEntry[];
  errors: { ref: string; error: string }[];
}

export type UploadOptions = {
  changeEvent?: string;
  submitEvent: string;
};

// Phoenix LiveView AsyncResult type for client-side use
export interface AsyncResult<T = unknown> {
  ok: boolean;
  loading: string[] | null;
  failed: any | null;
  result: T | null;
}

export interface SetupContext {
  createApp: typeof createSSRApp | typeof createApp;
  component: VueComponentInternal;
  props: Record<string, unknown>;
  slots: Record<string, () => unknown>;
  plugin: Plugin<[]>;
  el: Element;
  ssr: boolean;
}

export type VueIslandOptions = {
  resolve: (path: string) => ComponentOrComponentPromise | undefined | null;
  setup?: (context: SetupContext) => App;
};

export type VueIslandApp = {
  setup: (context: SetupContext) => App;
  resolve: (path: string) => ComponentOrComponentPromise;
};

export interface VueIslandHooks {
  LiveIslandsVueHook: ViewHook;
}
