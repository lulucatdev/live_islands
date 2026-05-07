import React, { useMemo, useState } from "react";
import { useEventReply } from "live_islands/react";

const toneClass = {
  sky: "border-sky-200 bg-sky-50 text-sky-700",
  emerald: "border-emerald-200 bg-emerald-50 text-emerald-700",
  violet: "border-violet-200 bg-violet-50 text-violet-700",
  amber: "border-amber-200 bg-amber-50 text-amber-800",
};

export function ShowcaseCommand({
  metrics = {},
  signals = [],
  activeSignal = {},
  revision = 1,
  pushEvent,
}) {
  const [selected, setSelected] = useState(activeSignal.id || "react");
  const reply = useEventReply("showcase-reply", {
    defaultValue: { message: "React reply waiting", revision },
  });
  const active = useMemo(
    () => signals.find((signal) => signal.id === selected) || signals[0],
    [signals, selected],
  );

  const run = () => {
    const signal = active?.id || "react";
    reply.execute({ signal });
    pushEvent?.("showcase-react-action", { action: `inspect-${signal}` });
  };

  return (
    <section
      data-testid="showcase-react-command"
      className="showcase-card rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
    >
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase text-sky-700">
            React island
          </p>
          <h3 className="mt-1 text-2xl font-bold text-zinc-950">
            Command deck
          </h3>
        </div>
        <span className="rounded-md bg-zinc-950 px-3 py-1 text-sm font-semibold text-white">
          rev {reply.data?.revision || revision}
        </span>
      </div>

      <div className="mt-5 grid grid-cols-4 gap-2">
        {Object.entries(metrics).map(([name, value]) => (
          <div key={name} className="rounded-md border border-zinc-100 p-3">
            <div className="text-xl font-bold text-zinc-950">{value}</div>
            <div className="text-xs font-semibold uppercase text-zinc-500">
              {name}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-5 grid gap-2">
        {signals.map((signal) => (
          <button
            key={signal.id}
            type="button"
            data-testid={`showcase-react-signal-${signal.id}`}
            className={`rounded-md border p-3 text-left transition ${
              selected === signal.id
                ? toneClass[signal.tone] || toneClass.sky
                : "border-zinc-200 bg-white text-zinc-700 hover:border-zinc-300"
            }`}
            onClick={() => setSelected(signal.id)}
          >
            <div className="flex items-center justify-between gap-3">
              <span className="font-semibold">{signal.label}</span>
              <span className="text-sm">{signal.score}</span>
            </div>
          </button>
        ))}
      </div>

      <div className="mt-5 rounded-md bg-zinc-950 p-4 text-white">
        <button
          type="button"
          data-testid="showcase-react-run"
          className="rounded-md bg-white px-3 py-2 text-sm font-semibold text-zinc-950 transition hover:bg-zinc-100"
          onClick={run}
        >
          Run command
        </button>
        <p
          data-testid="showcase-react-reply"
          className="mt-3 text-sm text-zinc-300"
        >
          {reply.data?.message}
        </p>
      </div>
    </section>
  );
}
