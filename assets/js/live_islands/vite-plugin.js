function hotUpdateType(path) {
  if (path.endsWith("css")) return "css-update";
  if (path.endsWith("js") || path.endsWith("ts") || path.endsWith("vue"))
    return "js-update";
  return null;
}

const jsonResponse = (res, statusCode, data) => {
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(data));
};

const jsonMiddleware = (req, res, next) => {
  let data = "";

  req.on("data", (chunk) => {
    data += chunk;
  });

  req.on("end", () => {
    try {
      req.body = JSON.parse(data);
      next();
    } catch (_error) {
      jsonResponse(res, 400, { error: "Invalid JSON" });
    }
  });

  req.on("error", (err) => {
    console.error(err);
    jsonResponse(res, 500, { error: "Internal Server Error" });
  });
};

function liveIslandsPlugin(opts = {}) {
  return {
    name: "live-islands",
    handleHotUpdate({ file, modules, server, timestamp }) {
      if (file.match(/\.(heex|ex)$/)) {
        const invalidatedModules = new Set();
        for (const mod of modules) {
          server.moduleGraph.invalidateModule(
            mod,
            invalidatedModules,
            timestamp,
            true,
          );
        }

        const updates = Array.from(invalidatedModules)
          .filter((mod) => mod.file && hotUpdateType(mod.file))
          .map((mod) => ({
            type: hotUpdateType(mod.file),
            path: mod.url,
            acceptedPath: mod.url,
            timestamp,
          }));

        server.ws.send({ type: "update", updates });

        return [];
      }
    },
    configureServer(server) {
      process.stdin.on("close", () => process.exit(0));
      process.stdin.resume();

      const path = opts.path || "/ssr_render";
      const entrypoint = opts.entrypoint || "./js/server.js";
      server.middlewares.use(function liveIslandsMiddleware(req, res, next) {
        if (req.method == "POST" && req.url.split("?", 1)[0] === path) {
          jsonMiddleware(req, res, async () => {
            try {
              const render = (await server.ssrLoadModule(entrypoint)).render;
              const html = await render(
                req.body.framework || "react",
                req.body.name,
                req.body.props,
                req.body.slots,
              );
              res.end(html);
            } catch (error) {
              server.ssrFixStacktrace(error);
              jsonResponse(res, 500, { error });
            }
          });
        } else {
          next();
        }
      });
    },
  };
}

module.exports = liveIslandsPlugin;
