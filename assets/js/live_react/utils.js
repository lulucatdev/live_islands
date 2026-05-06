import React from "react";
import { LiveReactProvider } from "./context";

function getHooks(props) {
  return {
    pushEvent: props.pushEvent,
    pushEventTo: props.pushEventTo,
    handleEvent: props.handleEvent,
    removeHandleEvent: props.removeHandleEvent,
    upload: props.upload,
    uploadTo: props.uploadTo,
    liveSocket: props.liveSocket,
    el: props.el,
  };
}

export function getComponentTree(
  Component,
  props,
  children,
  liveContext = props,
) {
  const componentInstance = React.createElement(Component, props, ...children);

  return React.createElement(
    LiveReactProvider,
    getHooks(liveContext),
    componentInstance,
  );
}
