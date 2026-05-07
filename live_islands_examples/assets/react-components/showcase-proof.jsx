import React from "react";

export function ShowcaseProof({
  testId = "showcase-react-proof",
  framework = "React",
  mode = "server-only",
  title = "Server proof",
  body = "Rendered by SSR.",
  metrics = [],
}) {
  return (
    <section
      data-testid={testId}
      className="showcase-card rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold uppercase text-sky-700">
            {framework}
          </p>
          <h3 className="mt-1 text-lg font-bold text-zinc-950">{title}</h3>
        </div>
        <span className="rounded-md bg-sky-50 px-2 py-1 text-xs font-semibold text-sky-700">
          {mode}
        </span>
      </div>
      <p className="mt-3 text-sm leading-6 text-zinc-600">{body}</p>
      <div className="mt-5 grid grid-cols-3 gap-2">
        {metrics.map((metric) => (
          <div key={metric.label} className="rounded-md bg-zinc-50 p-3">
            <div className="text-xs font-semibold uppercase text-zinc-500">
              {metric.label}
            </div>
            <div className="mt-1 text-sm font-bold text-zinc-950">
              {metric.value}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
