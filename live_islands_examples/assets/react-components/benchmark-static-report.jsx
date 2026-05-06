export function BenchmarkStaticReport({ metrics = {}, sections = [] }) {
  const totalScore =
    sections.reduce((total, section) => total + section.score, 0) /
    Math.max(sections.length, 1);

  return (
    <article
      data-testid="benchmark-server-report"
      className="rounded-md border border-zinc-200 bg-zinc-950 p-5 text-white"
    >
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold">
            Server-only executive summary
          </h2>
          <p className="text-sm text-zinc-300">
            Rendered by React SSR and never hydrated on the client.
          </p>
        </div>
        <div className="text-right">
          <div className="text-3xl font-bold">{Math.round(totalScore)}</div>
          <div className="text-xs uppercase text-zinc-400">scenario score</div>
        </div>
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-4">
        <Metric label="documents" value={metrics.documents} />
        <Metric label="formulas" value={metrics.formulas} />
        <Metric label="pdf pages" value={metrics.pdf_pages} />
        <Metric label="stream rows" value={metrics.stream_rows} />
      </div>
    </article>
  );
}

function Metric({ label, value }) {
  return (
    <div className="rounded border border-white/10 bg-white/5 p-3">
      <div className="text-2xl font-semibold">{value}</div>
      <div className="text-xs uppercase text-zinc-400">{label}</div>
    </div>
  );
}
