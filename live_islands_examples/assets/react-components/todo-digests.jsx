export function TodoSsrDigest({ tasks = [], metrics = {}, mode = "Launch" }) {
  const active = tasks.filter((task) => !task.done);
  const urgent = active.filter((task) => task.priority === "P0");

  return (
    <section
      data-testid="todo-ssr-digest"
      className="todo-card border border-zinc-900 bg-zinc-950 p-5 text-white shadow-xl"
    >
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-zinc-400">
            React server-only island
          </p>
          <h2 className="mt-1 text-2xl font-bold">Morning digest</h2>
        </div>
        <span className="rounded-full bg-white px-3 py-1 text-sm font-semibold text-zinc-950">
          {mode}
        </span>
      </div>
      <div className="mt-5 grid grid-cols-3 gap-3">
        <DigestMetric label="Open" value={metrics.open || 0} />
        <DigestMetric label="Done" value={metrics.done || 0} />
        <DigestMetric label="Urgent" value={urgent.length} />
      </div>
      <div className="mt-5 rounded-md border border-white/10 bg-white/5 p-4">
        <div className="text-sm font-semibold text-zinc-300">
          Next best task
        </div>
        <div className="mt-2 text-lg font-bold">
          {active[0]?.title || "All clear"}
        </div>
        <div className="mt-1 text-sm text-zinc-400">
          Rendered into the initial shell without a client hook.
        </div>
      </div>
    </section>
  );
}

export function TodoDeferredDigest({
  tasks = [],
  metrics = {},
  mode = "Launch",
}) {
  const risk = tasks.filter(
    (task) => !task.done && task.priority === "P0",
  ).length;
  const review = tasks.filter((task) => task.lane === "review").length;
  const doneRate = Math.round(
    ((metrics.done || 0) / Math.max(metrics.total || 1, 1)) * 100,
  );

  return (
    <section
      data-testid="todo-deferred-digest"
      className="todo-card border border-sky-200 bg-sky-50 p-5 shadow-sm"
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-sky-700">
            Deferred server island
          </p>
          <h3 className="mt-1 text-xl font-bold text-sky-950">
            Late-bound insight
          </h3>
        </div>
        <span className="rounded-full bg-white px-3 py-1 text-sm font-semibold text-sky-800 shadow-sm">
          {doneRate}%
        </span>
      </div>
      <p className="mt-4 text-sm leading-6 text-sky-800">
        {mode} mode has {risk} urgent task{risk === 1 ? "" : "s"} and {review}{" "}
        item{review === 1 ? "" : "s"} waiting for review.
      </p>
      <div className="mt-4 h-2 overflow-hidden rounded-full bg-white">
        <div
          className="h-full rounded-full bg-sky-600"
          style={{ width: `${doneRate}%` }}
        />
      </div>
    </section>
  );
}

function DigestMetric({ label, value }) {
  return (
    <div className="rounded-md border border-white/10 bg-white/5 p-3">
      <div className="text-2xl font-bold">{value}</div>
      <div className="mt-1 text-xs uppercase text-zinc-400">{label}</div>
    </div>
  );
}
