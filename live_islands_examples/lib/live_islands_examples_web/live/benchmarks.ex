defmodule LiveIslandsExamplesWeb.LiveBenchmarks do
  use LiveIslandsExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-brand">Benchmark Scenario</p>
        <h1 class="text-3xl font-bold">LiveIslands benchmark workbench</h1>
        <p class="max-w-3xl text-zinc-600">
          A production-size route that combines SSR content, server-only islands, deferred React
          hydration, Vue hydration, KaTeX rendering, and PDF.js rendering.
        </p>
      </div>

      <.react_server
        id="benchmark_server_report"
        name="BenchmarkStaticReport"
        metrics={@metrics}
        sections={@sections}
      />

      <.react_server
        id="benchmark_deferred_report"
        name="BenchmarkDeferredReport"
        metrics={@metrics}
        sections={@sections}
        defer={true}
        defer_timeout={5000}
        defer_cache_control="public, max-age=60"
      >
        <:fallback>
          <div
            data-testid="benchmark-deferred-fallback"
            class="rounded-md border border-sky-100 bg-sky-50 p-5 text-sky-800"
          >
            Loading deferred benchmark report
          </div>
        </:fallback>
      </.react_server>

      <.react_server
        id="benchmark_ssr_summary"
        name="BenchmarkSummary"
        metrics={@metrics}
        sections={@sections}
      />

      <.react
        id="benchmark_workbench"
        class="benchmark-island-shell"
        name="BenchmarkWorkbench"
        formula={@formula}
        sections={@sections}
        ssr={false}
        client={:idle}
        prefetch={:none}
      />

      <.vue
        id="benchmark_vue_probe"
        v-component="benchmark-probe"
        samples={@samples}
        message="Vue benchmark probe hydrated"
        v-ssr={false}
        client={:visible}
        prefetch={:idle}
      />
    </section>
    """
  end

  def mount(_params, _session, socket) do
    metrics = %{
      "documents" => 128,
      "formulas" => 96,
      "pdf_pages" => 12,
      "stream_rows" => 480,
      "ssr_sections" => 4
    }

    sections = [
      %{title: "Executive summary", score: 94, weight: "SSR"},
      %{title: "Formula renderer", score: 89, weight: "KaTeX"},
      %{title: "PDF renderer", score: 91, weight: "PDF.js"},
      %{title: "Island routing", score: 97, weight: "Page scope"}
    ]

    samples =
      for index <- 1..12 do
        %{
          id: index,
          label: "Sample #{index}",
          value: 70 + rem(index * 13, 29)
        }
      end

    socket =
      socket
      |> assign(:metrics, metrics)
      |> assign(:sections, sections)
      |> assign(:samples, samples)
      |> assign(
        :formula,
        "\\int_0^1 x^2\\,dx = \\frac{1}{3}\\quad\\text{and}\\quad e^{i\\pi}+1=0"
      )

    {:ok, socket}
  end
end
