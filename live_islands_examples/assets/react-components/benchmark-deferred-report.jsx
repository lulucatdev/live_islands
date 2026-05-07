export function BenchmarkDeferredReport({ metrics = {}, sections = [] }) {
  const maxScore = sections.reduce(
    (score, section) => Math.max(score, section.score),
    0,
  );

  return (
    <article
      data-testid="benchmark-deferred-report"
      className="rounded-md border border-sky-200 bg-sky-50 p-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold text-sky-950">
            Deferred server island report
          </h2>
          <p className="text-sm text-sky-700">
            Rendered by React SSR after the shell response, then inserted as
            static HTML.
          </p>
        </div>
        <div className="rounded bg-white px-3 py-2 text-right shadow-sm">
          <div className="text-2xl font-bold text-sky-950">{maxScore}</div>
          <div className="text-xs uppercase text-sky-700">top score</div>
        </div>
      </div>

      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        <Metric label="deferred documents" value={metrics.documents} />
        <Metric label="deferred formulas" value={metrics.formulas} />
        <Metric label="deferred pages" value={metrics.pdf_pages} />
      </div>
    </article>
  );
}

function Metric({ label, value }) {
  return (
    <div className="rounded border border-sky-100 bg-white p-3">
      <div className="text-2xl font-semibold text-sky-950">{value}</div>
      <div className="text-xs uppercase text-sky-700">{label}</div>
    </div>
  );
}
