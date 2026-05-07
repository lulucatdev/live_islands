import React, { useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useEventReply } from "live_islands/react";

const priorityTone = {
  P0: "border-rose-200 bg-rose-50 text-rose-700",
  P1: "border-amber-200 bg-amber-50 text-amber-700",
  P2: "border-sky-200 bg-sky-50 text-sky-700",
  P3: "border-emerald-200 bg-emerald-50 text-emerald-700",
};

const laneTone = {
  backlog: "bg-slate-100 text-slate-700",
  today: "bg-sky-100 text-sky-700",
  doing: "bg-amber-100 text-amber-800",
  review: "bg-violet-100 text-violet-700",
  done: "bg-emerald-100 text-emerald-700",
};

export function TodoWorkspace({
  todos = [],
  allTodos = [],
  activity = [],
  lanes = [],
  metrics = {},
  filter = "all",
  search = "",
  mode = "Launch",
  pushEvent,
}) {
  const [draft, setDraft] = useState({
    title: "",
    body: "",
    owner: "Mira",
    due: "17:00",
    lane: "today",
    priority: "P2",
    tags: "new",
    points: 3,
  });
  const [localSearch, setLocalSearch] = useState(search || "");
  const planner = useEventReply("todo-suggest", {
    defaultValue: {
      headline: "Ask the planner for a next move",
      confidence: 0,
      steps: ["The reply will come from LiveView without a page reload."],
    },
  });

  const normalizedActivity = useMemo(
    () => normalizeStream(activity).slice(0, 8),
    [activity],
  );
  const grouped = useMemo(() => {
    const byLane = new Map(lanes.map((lane) => [lane.id, []]));
    for (const todo of todos) {
      if (!byLane.has(todo.lane)) byLane.set(todo.lane, []);
      byLane.get(todo.lane).push(todo);
    }
    return byLane;
  }, [lanes, todos]);

  const updateDraft = (key, value) =>
    setDraft((current) => ({ ...current, [key]: value }));

  const createTodo = (event) => {
    event.preventDefault();
    if (!draft.title.trim()) return;
    pushEvent?.("todo-create", draft);
    setDraft((current) => ({
      ...current,
      title: "",
      body: "",
      tags: "new",
    }));
  };

  const setFilter = (nextFilter) => {
    pushEvent?.("todo-filter", { filter: nextFilter, search: localSearch });
  };

  const applySearch = (value) => {
    setLocalSearch(value);
    pushEvent?.("todo-filter", { filter, search: value });
  };

  return (
    <section data-testid="todo-workspace" className="grid gap-6">
      <div className="todo-card border border-zinc-200 bg-white p-5 shadow-sm">
        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
          <div className="min-w-0">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <p className="text-sm font-semibold uppercase tracking-wide text-zinc-500">
                  React island
                </p>
                <h2 className="mt-1 text-2xl font-bold text-zinc-950">
                  Animated task board
                </h2>
              </div>
              <span className="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1 text-sm font-medium text-zinc-700">
                {mode} mode
              </span>
            </div>

            <form
              className="mt-5 grid gap-3 rounded-md border border-zinc-200 bg-zinc-50 p-4"
              onSubmit={createTodo}
            >
              <div className="grid gap-3 md:grid-cols-2 2xl:grid-cols-[minmax(0,1fr)_160px_130px]">
                <label className="grid gap-1">
                  <span className="text-xs font-semibold uppercase text-zinc-500">
                    Task
                  </span>
                  <input
                    data-testid="todo-title-input"
                    className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                    value={draft.title}
                    placeholder="Write a sharp next action"
                    onChange={(event) =>
                      updateDraft("title", event.target.value)
                    }
                  />
                </label>
                <label className="grid gap-1">
                  <span className="text-xs font-semibold uppercase text-zinc-500">
                    Owner
                  </span>
                  <input
                    className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                    value={draft.owner}
                    onChange={(event) =>
                      updateDraft("owner", event.target.value)
                    }
                  />
                </label>
                <label className="grid gap-1">
                  <span className="text-xs font-semibold uppercase text-zinc-500">
                    Due
                  </span>
                  <input
                    className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                    value={draft.due}
                    onChange={(event) => updateDraft("due", event.target.value)}
                  />
                </label>
              </div>

              <textarea
                className="min-h-20 rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                value={draft.body}
                placeholder="Add context, acceptance criteria, or a tiny checklist"
                onChange={(event) => updateDraft("body", event.target.value)}
              />

              <div className="grid min-w-0 gap-3 md:grid-cols-2 2xl:grid-cols-[120px_120px_minmax(0,1fr)_110px_auto]">
                <select
                  className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                  value={draft.priority}
                  onChange={(event) =>
                    updateDraft("priority", event.target.value)
                  }
                >
                  {["P0", "P1", "P2", "P3"].map((priority) => (
                    <option key={priority}>{priority}</option>
                  ))}
                </select>
                <select
                  className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                  value={draft.lane}
                  onChange={(event) => updateDraft("lane", event.target.value)}
                >
                  {lanes.map((lane) => (
                    <option key={lane.id} value={lane.id}>
                      {lane.title}
                    </option>
                  ))}
                </select>
                <input
                  className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm md:col-span-2 2xl:col-span-1"
                  value={draft.tags}
                  placeholder="release, design"
                  onChange={(event) => updateDraft("tags", event.target.value)}
                />
                <input
                  type="number"
                  min="1"
                  max="13"
                  className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                  value={draft.points}
                  onChange={(event) =>
                    updateDraft("points", event.target.value)
                  }
                />
                <button
                  data-testid="todo-add-button"
                  type="submit"
                  className="rounded-md bg-zinc-950 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800 md:col-span-2 2xl:col-span-1"
                >
                  Add task
                </button>
              </div>
            </form>
          </div>

          <div className="rounded-md border border-zinc-200 bg-zinc-950 p-4 text-white">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-semibold uppercase tracking-wide text-zinc-400">
                  Event reply
                </p>
                <h3 className="mt-1 font-semibold">Planner signal</h3>
              </div>
              <button
                data-testid="todo-plan-button"
                type="button"
                className="rounded-md bg-white px-3 py-2 text-sm font-semibold text-zinc-950 transition hover:bg-zinc-100"
                onClick={() => planner.execute({ filter, search: localSearch })}
              >
                Ask
              </button>
            </div>
            <div className="mt-4 rounded-md border border-white/10 bg-white/5 p-4">
              <p data-testid="todo-plan-headline" className="font-semibold">
                {planner.data?.headline}
              </p>
              <p className="mt-1 text-sm text-zinc-300">
                Confidence {planner.data?.confidence || 0}%
              </p>
              <ol className="mt-3 grid gap-2 text-sm text-zinc-200">
                {(planner.data?.steps || []).map((step) => (
                  <li key={step} className="rounded bg-white/5 px-3 py-2">
                    {step}
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </div>
      </div>

      <div className="todo-card border border-zinc-200 bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2">
            {["all", "open", ...lanes.map((lane) => lane.id)].map((option) => (
              <button
                key={option}
                type="button"
                className={`rounded-md px-3 py-2 text-sm font-medium transition ${
                  filter === option
                    ? "bg-zinc-950 text-white"
                    : "border border-zinc-200 bg-white text-zinc-700 hover:bg-zinc-50"
                }`}
                onClick={() => setFilter(option)}
              >
                {labelize(option)}
              </button>
            ))}
          </div>
          <input
            data-testid="todo-search-input"
            className="w-full rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100 sm:w-64"
            value={localSearch}
            placeholder="Search tasks or tags"
            onChange={(event) => applySearch(event.target.value)}
          />
        </div>
      </div>

      <div className="grid gap-4 xl:grid-cols-5">
        {lanes.map((lane) => (
          <LaneColumn
            key={lane.id}
            lane={lane}
            todos={grouped.get(lane.id) || []}
            pushEvent={pushEvent}
          />
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <section className="todo-card border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm font-semibold uppercase tracking-wide text-zinc-500">
                LiveView state
              </p>
              <h3 className="mt-1 text-xl font-bold">System health</h3>
            </div>
            <button
              type="button"
              data-testid="todo-clear-done"
              className="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-50"
              onClick={() => pushEvent?.("todo-clear-done", {})}
            >
              Clear done
            </button>
          </div>
          <div className="mt-5 grid gap-3 sm:grid-cols-4">
            <HealthMetric label="Total tasks" value={metrics.total || 0} />
            <HealthMetric label="Story points" value={metrics.points || 0} />
            <HealthMetric
              label="Focus blocks"
              value={metrics.focus_sessions || 0}
            />
            <HealthMetric label="Rendered" value={allTodos.length} />
          </div>
        </section>

        <section className="todo-card border border-zinc-200 bg-white p-5 shadow-sm">
          <p className="text-sm font-semibold uppercase tracking-wide text-zinc-500">
            Stream activity
          </p>
          <ul data-testid="todo-activity" className="mt-4 grid gap-2">
            {normalizedActivity.map((event) => (
              <li
                key={event.__dom_id || event.id}
                className="flex items-center justify-between gap-3 rounded-md border border-zinc-100 bg-zinc-50 px-3 py-2 text-sm"
              >
                <span>{event.label}</span>
                <span className="text-xs text-zinc-500">{event.at}</span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </section>
  );
}

function LaneColumn({ lane, todos, pushEvent }) {
  return (
    <section className="min-h-72 rounded-md border border-zinc-200 bg-white/80 p-3 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span
            className={`rounded-full px-2 py-1 text-xs ${laneTone[lane.id]}`}
          >
            {lane.title}
          </span>
          <span className="text-xs text-zinc-500">{todos.length}</span>
        </div>
      </div>
      <div className="grid gap-3">
        <AnimatePresence initial={false}>
          {todos.map((todo) => (
            <TaskCard key={todo.id} todo={todo} pushEvent={pushEvent} />
          ))}
        </AnimatePresence>
      </div>
    </section>
  );
}

function TaskCard({ todo, pushEvent }) {
  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 18, scale: 0.96 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -12, scale: 0.96 }}
      transition={{ type: "spring", stiffness: 380, damping: 34 }}
      data-testid={`todo-card-${todo.id}`}
      className="group rounded-md border border-zinc-200 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-zinc-300 hover:shadow-md"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span
              className={`rounded border px-2 py-0.5 text-xs font-semibold ${
                priorityTone[todo.priority] || priorityTone.P2
              }`}
            >
              {todo.priority}
            </span>
            <span className="text-xs text-zinc-500">{todo.due}</span>
          </div>
          <h3 className="mt-3 text-sm font-bold leading-5 text-zinc-950">
            {todo.title}
          </h3>
        </div>
        <button
          type="button"
          className={`grid h-8 w-8 shrink-0 place-items-center rounded-md border text-sm font-bold transition ${
            todo.done
              ? "border-emerald-200 bg-emerald-50 text-emerald-700"
              : "border-zinc-200 bg-white text-zinc-400 hover:text-zinc-900"
          }`}
          aria-label={todo.done ? "Mark open" : "Mark done"}
          onClick={() => pushEvent?.("todo-toggle", { id: todo.id })}
        >
          {todo.done ? "OK" : ""}
        </button>
      </div>
      <p className="mt-3 line-clamp-3 text-sm leading-6 text-zinc-600">
        {todo.body}
      </p>
      <div className="mt-4 h-2 overflow-hidden rounded-full bg-zinc-100">
        <motion.div
          className="h-full rounded-full bg-zinc-950"
          initial={{ width: 0 }}
          animate={{ width: `${todo.progress || 0}%` }}
          transition={{ duration: 0.5, ease: "easeOut" }}
        />
      </div>
      <div className="mt-4 flex flex-wrap gap-1.5">
        {(todo.tags || []).map((tag) => (
          <span
            key={tag}
            className="rounded bg-zinc-100 px-2 py-1 text-xs font-medium text-zinc-600"
          >
            {tag}
          </span>
        ))}
      </div>
      <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-zinc-100 pt-3">
        <span className="text-xs font-medium text-zinc-500">
          {todo.owner} / {todo.points} pts
        </span>
        <div className="flex items-center gap-1">
          <select
            aria-label="Move lane"
            className="rounded-md border border-zinc-200 bg-white px-2 py-1 text-xs"
            value={todo.lane}
            onChange={(event) =>
              pushEvent?.("todo-move", {
                id: todo.id,
                lane: event.target.value,
              })
            }
          >
            {["backlog", "today", "doing", "review", "done"].map((lane) => (
              <option key={lane} value={lane}>
                {labelize(lane)}
              </option>
            ))}
          </select>
          <button
            type="button"
            className="rounded-md border border-zinc-200 bg-white px-2 py-1 text-xs font-medium text-zinc-500 transition hover:border-rose-200 hover:text-rose-700"
            onClick={() => pushEvent?.("todo-delete", { id: todo.id })}
          >
            Remove
          </button>
        </div>
      </div>
    </motion.article>
  );
}

function HealthMetric({ label, value }) {
  return (
    <div className="rounded-md border border-zinc-100 bg-zinc-50 p-4">
      <div className="text-2xl font-bold text-zinc-950">{value}</div>
      <div className="mt-1 text-xs font-semibold uppercase text-zinc-500">
        {label}
      </div>
    </div>
  );
}

function normalizeStream(entries) {
  return (entries || []).map((entry) => {
    if (Array.isArray(entry)) return entry[1] || {};
    return entry || {};
  });
}

function labelize(value) {
  return String(value)
    .replace(/-/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
