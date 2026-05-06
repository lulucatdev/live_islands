import React from "react";
import ReactDOM from "react-dom/client";
import { getComponentTree } from "./utils";
import { decodeCompactPatch } from "./compactPatch";
import { applyPatch } from "./jsonPatch";

function getAttributeJson(el, attributeName) {
  const data = el.getAttribute(attributeName);
  return data ? JSON.parse(data) : {};
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
  const LiveIslandsReactHook = {
    _render() {
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
        throw new Error("Component name must be provided");
      }

      this._Component = components[componentName];
      this._props = getProps(this);
      this._props = applyPatch(
        this._props,
        getDiff(this.el, "data-streams-diff"),
      );

      const isSSR = this.el.hasAttribute("data-ssr");

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
    },
    updated() {
      if (this._root) {
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
      }
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
