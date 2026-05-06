export function BenchmarkSummary({ metrics = {}, sections = [] }) {
  const totals = Object.entries(metrics);

  return (
    <section
      data-testid="benchmark-ssr-summary"
      className="rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
    >
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold">Benchmark SSR proof</h2>
          <p className="text-sm text-zinc-600">
            This island is rendered by SSR and left static in the initial HTML.
          </p>
        </div>
        <span className="rounded bg-emerald-50 px-2 py-1 text-sm font-medium text-emerald-700">
          SSR only
        </span>
      </div>

      <dl className="mt-5 grid gap-3 sm:grid-cols-5">
        {totals.map(([name, value]) => (
          <div key={name} className="rounded border border-zinc-100 p-3">
            <dt className="text-xs uppercase text-zinc-500">
              {name.replaceAll("_", " ")}
            </dt>
            <dd className="mt-1 text-2xl font-bold">{value}</dd>
          </div>
        ))}
      </dl>

      <div className="mt-5 grid gap-2 md:grid-cols-4">
        {sections.map((section) => (
          <div key={section.title} className="rounded bg-zinc-50 p-3">
            <div className="text-sm font-medium">{section.title}</div>
            <div className="mt-2 h-2 rounded bg-zinc-200">
              <div
                className="h-2 rounded bg-brand"
                style={{ width: `${section.score}%` }}
              />
            </div>
            <div className="mt-1 text-xs text-zinc-500">{section.weight}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
