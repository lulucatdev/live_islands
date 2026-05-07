import React, { useEffect, useMemo, useState } from "react";

export function TodoFocusTimer({ goal = 45, sessions = 0, pushEvent }) {
  const [running, setRunning] = useState(false);
  const [seconds, setSeconds] = useState(0);
  const totalSeconds = goal * 60;
  const progress = Math.min(100, Math.round((seconds / totalSeconds) * 100));

  useEffect(() => {
    if (!running) return undefined;
    const timer = window.setInterval(() => {
      setSeconds((current) => {
        const next = current + 1;
        if (next >= totalSeconds) {
          window.clearInterval(timer);
          setRunning(false);
          pushEvent?.("focus-complete", {});
        }
        return next;
      });
    }, 1000);

    return () => window.clearInterval(timer);
  }, [running, totalSeconds, pushEvent]);

  const label = useMemo(() => {
    const remaining = Math.max(totalSeconds - seconds, 0);
    const minutes = String(Math.floor(remaining / 60)).padStart(2, "0");
    const rest = String(remaining % 60).padStart(2, "0");
    return `${minutes}:${rest}`;
  }, [seconds, totalSeconds]);

  const start = () => {
    setRunning(true);
    pushEvent?.("focus-started", {});
  };

  return (
    <section
      data-testid="todo-focus-timer"
      className="todo-card border border-zinc-200 bg-white p-5 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-zinc-500">
            Visible hydration
          </p>
          <h3 className="mt-1 text-xl font-bold">Focus timer</h3>
        </div>
        <span className="rounded-full bg-violet-50 px-3 py-1 text-sm font-semibold text-violet-700">
          {sessions} blocks
        </span>
      </div>
      <div className="mt-5 grid place-items-center">
        <div
          className="grid h-40 w-40 place-items-center rounded-full border border-zinc-200 bg-zinc-50"
          style={{
            background: `conic-gradient(#18181b ${progress}%, #f4f4f5 ${progress}% 100%)`,
          }}
        >
          <div className="grid h-32 w-32 place-items-center rounded-full bg-white shadow-sm">
            <span className="font-mono text-3xl font-bold">{label}</span>
          </div>
        </div>
      </div>
      <div className="mt-5 grid grid-cols-2 gap-2">
        <button
          type="button"
          className="rounded-md bg-zinc-950 px-3 py-2 text-sm font-semibold text-white transition hover:bg-zinc-800"
          onClick={running ? () => setRunning(false) : start}
        >
          {running ? "Pause" : "Start"}
        </button>
        <button
          type="button"
          className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 transition hover:bg-zinc-50"
          onClick={() => {
            setRunning(false);
            setSeconds(0);
          }}
        >
          Reset
        </button>
      </div>
    </section>
  );
}
