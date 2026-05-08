// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "topbar";
import reactComponents from "../react-components";
import vueComponents from "../vue-components";
import { getIslandHooks } from "live_islands";
import "../css/app.css";

const benchmarkEventTypes = [
  "live-islands:mounted",
  "live-islands:hydrated",
  "live-islands:deferred:load",
  "live-islands:deferred:error",
  "live-islands:prefetch:load",
  "live-islands:prefetch:modulepreload",
  "live-islands:prefetch:error",
];
const benchmarkStoreKey = "__liveIslandsBrowserBenchmark";

function setupBenchmarkRecorder() {
  const store =
    window[benchmarkStoreKey] ||
    (window[benchmarkStoreKey] = {
      events: [],
      installed: false,
      startedAt: new Date().toISOString(),
    });

  if (store.installed) return store;

  benchmarkEventTypes.forEach((type) => {
    window.addEventListener(type, (event) => {
      const detail = event.detail || {};
      const el = detail.el;

      store.events.push({
        type,
        at: Math.round(performance.now()),
        framework:
          detail.framework || el?.getAttribute?.("data-framework") || null,
        name: detail.name || el?.getAttribute?.("data-name") || null,
        client: el?.getAttribute?.("data-client") || null,
        prefetch: el?.getAttribute?.("data-prefetch") || null,
        bytes: Number(detail.bytes || 0),
        duration: Number(detail.duration || 0),
        count: Number(detail.count || 0),
        message: detail.message || null,
      });
      store.events = store.events.slice(-120);
    });
  });

  store.installed = true;
  return store;
}

const BenchmarkOnlineRunner = {
  mounted() {
    setupBenchmarkRecorder();
    this.running = false;
    this.handleClick = async (event) => {
      const button = event.target.closest("[data-benchmark-online-start]");
      if (!button || this.running) return;

      event.preventDefault();
      this.running = true;
      this.pushEvent("benchmark-online-start", {});

      try {
        const { runOnlineBenchmark } = await import(
          "./benchmark_online_runner"
        );
        const result = await runOnlineBenchmark();
        this.pushEvent("benchmark-online-result", { result });
      } catch (error) {
        this.pushEvent("benchmark-online-error", {
          message: error?.message || String(error),
        });
      } finally {
        this.running = false;
      }
    };

    this.el.addEventListener("click", this.handleClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick);
  },
};

const islandHooks = getIslandHooks({
  react: reactComponents,
  vue: vueComponents,
  prefetch: { scope: "page" },
});
const hooks = { ...islandHooks, BenchmarkOnlineRunner };

setupBenchmarkRecorder();

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks,
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
