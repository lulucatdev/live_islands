import React from "react";
import ReactDOM from "react-dom/client";
import { getComponentTree } from "./utils";
import { decodeCompactPatch } from "./compactPatch";
import { applyPatch } from "./jsonPatch";
import { normalizeReactIslandApp } from "./app";
import { scheduleHydration } from "../hydration";
import { describeIslandElement } from "../diagnostics.js";

function getAttributeJson(el, attributeName) {
  const data = el.getAttribute(attributeName);
  if (!data) return {};

  try {
    return JSON.parse(data);
  } catch (error) {
    throw new Error(
      `[LiveIslands][react] Failed to parse ${attributeName} for ${describeIslandElement(el)}: ${error.message}`,
    );
  }
}

function getChildren(hook) {
  const dataSlots = getAttributeJson(hook.el, "data-slots");

  if (!dataSlots?.default) {
    return [];
  }

  return [
    React.createElement("div", {
      dangerouslySetInnerHTML: { __html: atob(dataSlots.default).trim() },
    }),
  ];
}

function getProps(hook) {
  return {
    ...getAttributeJson(hook.el, "data-props"),
    ...getHandlers(hook),
    pushEvent: hook.pushEvent.bind(hook),
    pushEventTo: hook.pushEventTo.bind(hook),
    handleEvent: hook.handleEvent.bind(hook),
    removeHandleEvent: hook.removeHandleEvent.bind(hook),
    upload: hook.upload.bind(hook),
    uploadTo: hook.uploadTo.bind(hook),
  };
}

function getLiveContext(hook) {
  return {
    pushEvent: hook.pushEvent.bind(hook),
    pushEventTo: hook.pushEventTo.bind(hook),
    handleEvent: hook.handleEvent.bind(hook),
    removeHandleEvent: hook.removeHandleEvent.bind(hook),
    upload: hook.upload.bind(hook),
    uploadTo: hook.uploadTo.bind(hook),
    liveSocket: hook.liveSocket,
    el: hook.el,
  };
}

function getDiff(el, attributeName) {
  return decodeCompactPatch(el.getAttribute(attributeName));
}

function getHandlers(hook) {
  const handlers = getAttributeJson(hook.el, "data-handlers");
  const result = {};

  for (const handlerName in handlers) {
    const reactName = `on${handlerName.charAt(0).toUpperCase()}${handlerName.slice(1)}`;
    result[reactName] = (event) => {
      const parsedOps = JSON.parse(handlers[handlerName]);
      const replacedOps = parsedOps.map(([op, args, ...other]) => {
        if (op === "push" && !args.value) args.value = event;
        return [op, args, ...other];
      });
      hook.liveSocket.execJS(hook.el, JSON.stringify(replacedOps));
    };
  }

  return result;
}

export function getHooks(components) {
  const app = normalizeReactIslandApp(components);

  const LiveIslandsReactHook = {
    _render() {
      if (!this._root || !this._Component) return;

      const tree = getComponentTree(
        this._Component,
        this._props,
        getChildren(this),
        getLiveContext(this),
      );
      this._root.render(tree);
    },
    mounted() {
      const componentName = this.el.getAttribute("data-name");
      if (!componentName) {
        throw new Error(
          `[LiveIslands][react] Component name must be provided for ${describeIslandElement(this.el)}.`,
        );
      }

      this._props = getProps(this);
      this._props = applyPatch(
        this._props,
        getDiff(this.el, "data-streams-diff"),
      );

      window.dispatchEvent(
        new CustomEvent("live-islands:mounted", { detail: { el: this.el } }),
      );

      this._cancelHydration = scheduleHydration(this.el, async () => {
        this._Component = await app.resolve(componentName);
        const isSSR = this.el.getAttribute("data-ssr") === "true";

        if (isSSR) {
          const tree = getComponentTree(
            this._Component,
            this._props,
            getChildren(this),
            getLiveContext(this),
          );
          this._root = ReactDOM.hydrateRoot(this.el, tree);
        } else {
          this._root = ReactDOM.createRoot(this.el);
          this._render();
        }
      });
    },
    updated() {
      if (this.el.getAttribute("data-use-diff") === "true") {
        this._props = applyPatch(
          this._props,
          getDiff(this.el, "data-props-diff"),
        );
        Object.assign(this._props, getHandlers(this));
      } else {
        this._props = getProps(this);
      }
      this._props = applyPatch(
        this._props,
        getDiff(this.el, "data-streams-diff"),
      );
      this._render();
    },
    reconnected() {
      this._props = getProps(this);
      this._props = applyPatch(
        this._props,
        getDiff(this.el, "data-streams-diff"),
      );
      if (this._root) this._render();
    },
    destroyed() {
      if (this._cancelHydration) this._cancelHydration();

      if (this._root) {
        window.addEventListener(
          "phx:page-loading-stop",
          () => this._root.unmount(),
          { once: true },
        );
      }
    },
  };

  return { LiveIslandsReactHook };
}
