import React, { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

const actions = [
  {
    id: "plan-today",
    title: "Plan today",
    body: "Move actionable backlog items into the Today lane.",
  },
  {
    id: "ship-review",
    title: "Ship review",
    body: "Mark review-lane work as completed.",
  },
  {
    id: "clear-done",
    title: "Clear done",
    body: "Archive completed work from the board.",
  },
];

export function TodoCommandCenter({ metrics = {}, pushEvent }) {
  const [open, setOpen] = useState(false);

  return (
    <section
      data-testid="todo-command-center"
      className="todo-card border border-zinc-200 bg-zinc-950 p-5 text-white shadow-sm"
      onPointerEnter={() => setOpen(true)}
      onFocus={() => setOpen(true)}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-zinc-400">
            Interaction hydration
          </p>
          <h3 className="mt-1 text-xl font-bold">Command center</h3>
        </div>
        <button
          type="button"
          data-testid="todo-command-toggle"
          className="rounded-md bg-white px-3 py-2 text-sm font-semibold text-zinc-950 transition hover:bg-zinc-100"
          onClick={() => setOpen((value) => !value)}
        >
          {open ? "Close" : "Open"}
        </button>
      </div>
      <p className="mt-3 text-sm leading-6 text-zinc-300">
        This panel is server-rendered, then waits for intent before hydrating
        and loading its island chunk.
      </p>
      <div className="mt-4 grid grid-cols-3 gap-2 text-center">
        <MiniStat label="Open" value={metrics.open || 0} />
        <MiniStat label="Done" value={metrics.done || 0} />
        <MiniStat label="P0" value={metrics.p0 || 0} />
      </div>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.22 }}
            className="overflow-hidden"
          >
            <div className="mt-4 grid gap-2">
              {actions.map((action) => (
                <button
                  key={action.id}
                  type="button"
                  data-testid={`todo-command-${action.id}`}
                  className="rounded-md border border-white/10 bg-white/5 p-3 text-left transition hover:border-white/20 hover:bg-white/10"
                  onClick={() =>
                    pushEvent?.("command-action", { action: action.id })
                  }
                >
                  <div className="font-semibold">{action.title}</div>
                  <div className="mt-1 text-sm text-zinc-300">
                    {action.body}
                  </div>
                </button>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </section>
  );
}

function MiniStat({ label, value }) {
  return (
    <div className="rounded-md border border-white/10 bg-white/5 px-2 py-3">
      <div className="text-xl font-bold">{value}</div>
      <div className="text-xs uppercase text-zinc-400">{label}</div>
    </div>
  );
}
