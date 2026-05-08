defmodule LiveIslandsExamplesWeb.LiveBenchmarks do
  use LiveIslandsExamplesWeb, :live_view

  @online_budgets %{
    initial_total_bytes: 700_000,
    initial_js_bytes: 560_000,
    heavy_interaction_js_bytes: 2_100_000,
    heavy_interaction_duration_ms: 1_000,
    runtime_errors: 0
  }

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

      <.online_runner
        status={@online_status}
        result={@online_result}
        checks={@online_checks}
        error={@online_error}
      />

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
      |> assign(:online_status, :idle)
      |> assign(:online_result, nil)
      |> assign(:online_checks, [])
      |> assign(:online_error, nil)

    {:ok, socket}
  end

  def handle_event("benchmark-online-start", _params, socket) do
    socket =
      socket
      |> assign(:online_status, :running)
      |> assign(:online_error, nil)

    {:noreply, socket}
  end

  def handle_event("benchmark-online-result", %{"result" => result}, socket) do
    result = normalize_online_result(result)

    socket =
      socket
      |> assign(:online_status, :complete)
      |> assign(:online_result, result)
      |> assign(:online_checks, online_checks(result))
      |> assign(:online_error, nil)

    {:noreply, socket}
  end

  def handle_event("benchmark-online-error", %{"message" => message}, socket) do
    socket =
      socket
      |> assign(:online_status, :error)
      |> assign(:online_error, message || "Browser benchmark failed.")

    {:noreply, socket}
  end

  attr :status, :atom, required: true
  attr :result, :map, default: nil
  attr :checks, :list, default: []
  attr :error, :string, default: nil

  defp online_runner(assigns) do
    ~H"""
    <section
      id="benchmark-online-runner"
      data-testid="benchmark-online-runner"
      phx-hook="BenchmarkOnlineRunner"
      class="scroll-mt-24 rounded-md border border-zinc-200 bg-white p-5 shadow-sm"
    >
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p class="text-sm font-semibold uppercase tracking-wide text-brand">
            Browser measurement
          </p>
          <h2 class="mt-1 text-2xl font-bold">Run this benchmark in the browser</h2>
          <p class="mt-2 max-w-3xl text-sm leading-6 text-zinc-600">
            This probes the current page with the browser Performance API, triggers
            the deferred report, hydrates the visible Vue probe, and runs the
            PDF.js + KaTeX interaction. The release gate still lives in
            <code class="rounded bg-zinc-100 px-1 py-0.5">make benchmark</code>.
          </p>
        </div>

        <button
          type="button"
          data-benchmark-online-start
          data-testid="benchmark-run-online"
          disabled={@status == :running}
          class="rounded-md bg-zinc-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-zinc-800 disabled:cursor-wait disabled:opacity-60"
        >
          {online_button_label(@status)}
        </button>
      </div>

      <div class="mt-5 rounded-md border border-zinc-100 bg-zinc-50 p-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <p data-testid="benchmark-online-status" class="text-sm font-semibold text-zinc-700">
            {online_status_label(@status)}
          </p>
          <p :if={@result} class="text-xs font-semibold uppercase text-zinc-500">
            {@result.measured_at}
          </p>
        </div>

        <p :if={@error} data-testid="benchmark-online-error" class="mt-3 text-sm font-semibold text-rose-700">
          {@error}
        </p>

        <div
          :if={@result}
          data-testid="benchmark-online-result"
          class="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
        >
          <.online_metric
            testid="benchmark-online-initial-total"
            label="Initial total"
            value={format_bytes(@result.page.network.total_bytes)}
          />
          <.online_metric
            testid="benchmark-online-initial-js"
            label="Initial JS"
            value={format_bytes(@result.page.network.js_bytes)}
          />
          <.online_metric
            testid="benchmark-online-heavy-duration"
            label="Heavy interaction"
            value={format_ms(@result.interaction.duration)}
          />
          <.online_metric
            testid="benchmark-online-heavy-js"
            label="Heavy JS"
            value={format_bytes(@result.interaction.network.js_bytes)}
          />
          <.online_metric
            label="Hydrated islands"
            value={@result.runtime.hydrated_count}
          />
          <.online_metric
            label="Deferred loads"
            value={@result.runtime.deferred_loaded_count}
          />
          <.online_metric
            label="Prefetch loads"
            value={@result.runtime.prefetch_loaded_count}
          />
          <.online_metric
            label="Runtime errors"
            value={@result.runtime.error_count}
          />
        </div>

        <div :if={@result} class="mt-4 grid gap-4 lg:grid-cols-2">
          <div>
            <p class="text-sm font-semibold text-zinc-700">Largest initial requests</p>
            <div class="mt-2 grid gap-2">
              <.request_row :for={request <- @result.page.network.top_requests} request={request} />
            </div>
          </div>

          <div>
            <p class="text-sm font-semibold text-zinc-700">Online budget checks</p>
            <div data-testid="benchmark-online-checks" class="mt-2 grid gap-2">
              <.check_row :for={check <- @checks} check={check} />
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :testid, :string, default: nil

  defp online_metric(assigns) do
    ~H"""
    <div data-testid={@testid} class="rounded-md border border-zinc-200 bg-white p-3">
      <div class="text-xs font-semibold uppercase text-zinc-500">{@label}</div>
      <div class="mt-1 text-xl font-bold text-zinc-950">{@value}</div>
    </div>
    """
  end

  attr :request, :map, required: true

  defp request_row(assigns) do
    ~H"""
    <div class="grid gap-2 rounded-md border border-zinc-200 bg-white p-3 text-sm md:grid-cols-[minmax(0,1fr)_90px]">
      <div class="min-w-0">
        <div class="truncate font-medium text-zinc-800">{@request.url}</div>
        <div class="text-xs uppercase text-zinc-500">{@request.kind}</div>
      </div>
      <div class="font-semibold text-zinc-950 md:text-right">{format_bytes(@request.bytes)}</div>
    </div>
    """
  end

  attr :check, :map, required: true

  defp check_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 rounded-md border border-zinc-200 bg-white p-3 text-sm">
      <div>
        <div class="font-medium text-zinc-800">{@check.label}</div>
        <div class="text-xs text-zinc-500">
          {@check.value_label} / budget {@check.budget_label}
        </div>
      </div>
      <span class={[
        "rounded-md px-2 py-1 text-xs font-semibold uppercase",
        if(@check.pass, do: "bg-emerald-50 text-emerald-700", else: "bg-amber-50 text-amber-800")
      ]}>
        {if @check.pass, do: "pass", else: "watch"}
      </span>
    </div>
    """
  end

  defp online_button_label(:running), do: "Measuring..."
  defp online_button_label(:complete), do: "Run again"
  defp online_button_label(:error), do: "Retry measurement"
  defp online_button_label(_), do: "Start measurement"

  defp online_status_label(:running), do: "Measuring current browser session..."
  defp online_status_label(:complete), do: "Measurement complete."
  defp online_status_label(:error), do: "Measurement failed."
  defp online_status_label(_), do: "Ready to measure this browser session."

  defp normalize_online_result(result) do
    %{
      measured_at: string(result["measuredAt"]),
      mode: string(result["mode"]),
      page: %{
        path: string(get_in(result, ["page", "path"])),
        network: normalize_network(get_in(result, ["page", "network"]) || %{}),
        timings: %{
          response_end: integer(get_in(result, ["page", "timings", "responseEnd"])),
          dom_content_loaded: integer(get_in(result, ["page", "timings", "domContentLoaded"])),
          load_event_end: integer(get_in(result, ["page", "timings", "loadEventEnd"])),
          first_contentful_paint: integer(get_in(result, ["page", "timings", "firstContentfulPaint"]))
        }
      },
      interaction: %{
        duration: integer(get_in(result, ["interaction", "duration"])),
        total_duration: integer(get_in(result, ["interaction", "totalDuration"])),
        status: string(get_in(result, ["interaction", "status"])),
        network: normalize_network(get_in(result, ["interaction", "network"]) || %{})
      },
      runtime: %{
        event_count: integer(get_in(result, ["runtime", "eventCount"])),
        mounted_count: integer(get_in(result, ["runtime", "mountedCount"])),
        hydrated_count: integer(get_in(result, ["runtime", "hydratedCount"])),
        deferred_loaded_count: integer(get_in(result, ["runtime", "deferredLoadedCount"])),
        prefetch_loaded_count: integer(get_in(result, ["runtime", "prefetchLoadedCount"])),
        modulepreload_count: integer(get_in(result, ["runtime", "modulepreloadCount"])),
        error_count: integer(get_in(result, ["runtime", "errorCount"])),
        manifest_count: length(get_in(result, ["runtime", "manifest"]) || [])
      }
    }
  end

  defp normalize_network(network) do
    %{
      request_count: integer(network["requestCount"]),
      total_bytes: integer(network["totalBytes"]),
      unique_bytes: integer(network["uniqueBytes"]),
      document_bytes: integer(network["documentBytes"]),
      js_bytes: integer(network["jsBytes"]),
      css_bytes: integer(network["cssBytes"]),
      fetch_bytes: integer(network["fetchBytes"]),
      image_bytes: integer(network["imageBytes"]),
      font_bytes: integer(network["fontBytes"]),
      top_requests: normalize_requests(network["topRequests"] || [])
    }
  end

  defp normalize_requests(requests) when is_list(requests) do
    Enum.map(requests, fn request ->
      %{
        url: string(request["url"]),
        kind: string(request["kind"]),
        bytes: integer(request["bytes"]),
        duration: integer(request["duration"])
      }
    end)
  end

  defp normalize_requests(_), do: []

  defp online_checks(result) do
    [
      online_check(
        "Initial route bytes",
        result.page.network.total_bytes,
        @online_budgets.initial_total_bytes,
        :bytes
      ),
      online_check(
        "Initial JavaScript bytes",
        result.page.network.js_bytes,
        @online_budgets.initial_js_bytes,
        :bytes
      ),
      online_check(
        "Heavy interaction JavaScript",
        result.interaction.network.js_bytes,
        @online_budgets.heavy_interaction_js_bytes,
        :bytes
      ),
      online_check(
        "Heavy interaction duration",
        result.interaction.duration,
        @online_budgets.heavy_interaction_duration_ms,
        :ms
      ),
      online_check(
        "Runtime errors",
        result.runtime.error_count,
        @online_budgets.runtime_errors,
        :count
      )
    ]
  end

  defp online_check(label, value, budget, unit) do
    %{
      label: label,
      value: value,
      budget: budget,
      value_label: format_value(value, unit),
      budget_label: format_value(budget, unit),
      pass: value <= budget
    }
  end

  defp format_value(value, :bytes), do: format_bytes(value)
  defp format_value(value, :ms), do: format_ms(value)
  defp format_value(value, :count), do: Integer.to_string(value)

  defp format_ms(nil), do: "n/a"
  defp format_ms(value), do: "#{integer(value)} ms"

  defp format_bytes(nil), do: "n/a"

  defp format_bytes(value) do
    value = integer(value)

    cond do
      value >= 1_048_576 -> "#{Float.round(value / 1_048_576, 2)} MiB"
      value >= 1024 -> "#{Float.round(value / 1024, 1)} KiB"
      true -> "#{value} B"
    end
  end

  defp integer(nil), do: 0
  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: round(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp integer(_), do: 0

  defp string(nil), do: ""
  defp string(value) when is_binary(value), do: value
  defp string(value), do: to_string(value)
end
