import React from "react";

function createBenchmarkPdf() {
  const stream = [
    "BT",
    "/F1 18 Tf",
    "50 245 Td",
    "(LiveIslands benchmark PDF) Tj",
    "0 -32 Td",
    "/F1 11 Tf",
    "(This PDF is generated in-browser and rendered with PDF.js.) Tj",
    "0 -20 Td",
    "(It is intentionally loaded after user intent.) Tj",
    "ET",
  ].join("\n");

  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    [
      "<< /Type /Page",
      "/Parent 2 0 R",
      "/MediaBox [0 0 420 300]",
      "/Resources << /Font << /F1 5 0 R >> >>",
      "/Contents 4 0 R",
      ">>",
    ].join("\n"),
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];

  let body = "%PDF-1.4\n";
  const offsets = [0];

  objects.forEach((object, index) => {
    offsets.push(body.length);
    body += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });

  const xrefOffset = body.length;
  body += `xref\n0 ${objects.length + 1}\n`;
  body += "0000000000 65535 f \n";
  offsets.slice(1).forEach((offset) => {
    body += `${String(offset).padStart(10, "0")} 00000 n \n`;
  });
  body += [
    "trailer",
    `<< /Size ${objects.length + 1} /Root 1 0 R >>`,
    "startxref",
    String(xrefOffset),
    "%%EOF",
  ].join("\n");

  return new TextEncoder().encode(body);
}

export class BenchmarkWorkbench extends React.Component {
  canvasRef = React.createRef();

  state = {
    status: "idle",
    mathHtml: "",
    report: null,
  };

  renderHeavyArtifacts = async () => {
    const { formula } = this.props;

    performance.mark("live-islands-benchmark-heavy-start");
    this.setState({ status: "loading" });

    const [katexModule, pdfjs] = await Promise.all([
      import("katex"),
      import("pdfjs-dist/build/pdf.mjs"),
      import("katex/dist/katex.min.css"),
    ]);

    pdfjs.GlobalWorkerOptions.workerSrc = new URL(
      "pdfjs-dist/build/pdf.worker.min.mjs",
      import.meta.url,
    ).toString();

    const pdf = await pdfjs.getDocument({ data: createBenchmarkPdf() }).promise;
    const page = await pdf.getPage(1);
    const viewport = page.getViewport({ scale: 1.5 });
    const canvas = this.canvasRef.current;
    const context = canvas.getContext("2d");

    canvas.width = viewport.width;
    canvas.height = viewport.height;

    await page.render({ canvasContext: context, viewport }).promise;

    const katex = katexModule.default || katexModule;
    this.setState({
      mathHtml: katex.renderToString(formula, {
        displayMode: true,
        throwOnError: false,
      }),
    });

    const finished = performance.now();
    performance.mark("live-islands-benchmark-heavy-end");
    performance.measure(
      "live-islands-benchmark-heavy",
      "live-islands-benchmark-heavy-start",
      "live-islands-benchmark-heavy-end",
    );

    this.setState({
      report: {
        pages: pdf.numPages,
        width: Math.round(viewport.width),
        height: Math.round(viewport.height),
        finished: Math.round(finished),
      },
      status: "ready",
    });
  };

  render() {
    const { formula, sections = [] } = this.props;
    const { status, mathHtml, report } = this.state;

    return (
      <section
        data-testid="benchmark-workbench"
        className="rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
      >
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold">
              Interactive heavy workbench
            </h2>
            <p className="text-sm text-zinc-600">
              The island hydrates normally, but KaTeX and PDF.js are imported
              only after user intent.
            </p>
          </div>
          <button
            type="button"
            data-testid="benchmark-render-heavy"
            className="rounded bg-black px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
            disabled={status === "loading"}
            onClick={this.renderHeavyArtifacts}
          >
            {status === "loading" ? "Rendering..." : "Render PDF + KaTeX"}
          </button>
        </div>

        <div className="mt-5 grid gap-5 lg:grid-cols-[1fr_360px]">
          <div className="rounded border border-zinc-100 bg-zinc-50 p-4">
            <div className="text-sm font-medium text-zinc-600">
              KaTeX output
            </div>
            <div
              data-testid="benchmark-katex-output"
              className="mt-4 min-h-24 overflow-x-auto rounded bg-white p-4"
              dangerouslySetInnerHTML={{
                __html:
                  mathHtml ||
                  '<span class="text-zinc-400">Formula renderer is deferred.</span>',
              }}
            />
          </div>

          <div className="rounded border border-zinc-100 bg-zinc-50 p-4">
            <div className="text-sm font-medium text-zinc-600">
              PDF.js canvas
            </div>
            <canvas
              ref={this.canvasRef}
              data-testid="benchmark-pdf-canvas"
              className="mt-4 w-full rounded border border-zinc-200 bg-white"
              width="420"
              height="300"
            />
          </div>
        </div>

        <div className="mt-5 grid gap-3 md:grid-cols-4">
          {sections.map((section) => (
            <div key={section.title} className="rounded bg-zinc-50 p-3">
              <div className="text-sm font-medium">{section.title}</div>
              <div className="mt-1 text-xs uppercase text-zinc-500">
                {section.weight}
              </div>
            </div>
          ))}
        </div>

        <p data-testid="benchmark-heavy-report" className="mt-4 text-sm">
          {report
            ? `Rendered ${report.pages} PDF page at ${report.width}x${report.height} after ${report.finished}ms.`
            : "Heavy render not started."}
        </p>
      </section>
    );
  }
}
