defmodule LiveIslandsExamplesWeb.LiveShowcase do
  use Phoenix.LiveView, layout: false

  import LiveIslands

  alias Phoenix.LiveView.JS

  use Phoenix.VerifiedRoutes,
    endpoint: LiveIslandsExamplesWeb.Endpoint,
    router: LiveIslandsExamplesWeb.Router,
    statics: LiveIslandsExamplesWeb.static_paths()

  @features [
    %{
      id: "react-vue",
      number: "01",
      title: "React + Vue parity",
      short: "Both frameworks render, hydrate, and talk to LiveView on one page.",
      body: "Use this page to compare the React command deck and Vue signal board side by side. Both are SSR-rendered first, then hydrated by the route-level island runtime.",
      tags: ["React", "Vue", "SSR", "events"],
      proof: [
        "React and Vue both appear in initial HTML",
        "Both islands hydrate with explicit client policies",
        "Both islands send events back through LiveView"
      ]
    },
    %{
      id: "ssr-static",
      number: "02",
      title: "SSR + server-only",
      short: "Static React and Vue HTML without island hooks.",
      body: "This page is the zero-hydration proof. React and Vue components render on the server, but the resulting DOM has no LiveView island hook.",
      tags: ["SSR", "server-only", "zero hydration"],
      proof: [
        "React server proof has no phx-hook",
        "Vue server proof has no phx-hook",
        "The page keeps framework HTML inspectable"
      ]
    },
    %{
      id: "lazy-deferred",
      number: "03",
      title: "Lazy + deferred islands",
      short: "Delay client work and fetch server HTML only when it is needed.",
      body: "This page separates deferred server islands from visible hydration. The top block fetches static HTML after the shell; the lower block hydrates Vue only after it enters the viewport.",
      tags: ["deferred", "visible", "lazy"],
      proof: [
        "Deferred React and Vue fallbacks ship in initial HTML",
        "Deferred final HTML is fetched after page load",
        "The Vue board hydrates only when visible"
      ]
    },
    %{
      id: "liveview-events",
      number: "04",
      title: "LiveView control plane",
      short: "Native LiveView forms, streams, JS commands, and island event replies.",
      body: "This page shows the server-owned workflow. LiveView validates the form, streams events, toggles UI with Phoenix.LiveView.JS, and receives island replies.",
      tags: ["LiveView", "forms", "streams", "event reply"],
      proof: [
        "Native form validation stays in LiveView",
        "Server streams update beside islands",
        "React event replies round-trip through the socket"
      ]
    },
    %{
      id: "benchmarks",
      number: "05",
      title: "Benchmark lab",
      short: "The performance case stays separate from the product demos.",
      body: "This page points to the dedicated benchmark route, including the online browser probe for quick checks and the automated suite that guards every release.",
      tags: ["budgets", "online probe", "release checks"],
      proof: [
        "Home route has its own lightweight budget",
        "The browser can start a page-local measurement",
        "Release comparisons are generated from benchmark artifacts"
      ]
    }
  ]

  def render(assigns) do
    ~H"""
    <main
      data-live-islands-page={@page_path}
      data-testid="showcase-site"
      class="showcase-shell min-h-screen bg-[#f5f7fb] text-zinc-950"
    >
      <.site_header features={@features} active={@active_feature_id} />

      <%= if @feature do %>
        <.feature_page
          feature={@feature}
          features={@features}
          active_signal={@active_signal}
          event_count={@event_count}
          metrics={@metrics}
          native_form={@native_form}
          proof_metrics={@proof_metrics}
          server_revision={@server_revision}
          signals={@signals}
          socket={@socket}
          streams={@streams}
        />
      <% else %>
        <.overview features={@features} />
      <% end %>
    </main>
    """
  end

  def mount(params, _session, socket) do
    feature = feature_by_id(params["feature"])
    page_path = if feature, do: feature_path(feature), else: "/"

    socket =
      socket
      |> LiveIslands.put_asset_profile(:islands)
      |> assign(:page_title, page_title(feature))
      |> assign(:feature, feature)
      |> assign(:active_feature_id, if(feature, do: feature.id, else: nil))
      |> assign(:page_path, page_path)
      |> assign(:features, @features)
      |> assign(:signals, signals())
      |> assign(:active_signal, hd(signals()))
      |> assign(:metrics, %{react: 7, vue: 7, ssr: 4, lazy: 5})
      |> assign(:proof_metrics, proof_metrics())
      |> assign(:native_form, native_form(%{"name" => "Release cockpit"}))
      |> assign(:server_revision, 1)
      |> assign(:event_count, 3)
      |> stream(:events, initial_events())

    {:ok, socket}
  end

  def handle_event("showcase-reply", %{"signal" => signal_id}, socket) do
    signal = signal_by_id(signal_id)

    socket =
      socket
      |> bump_revision()
      |> log_event("React command inspected #{signal.label}", "sky")

    {:reply, %{message: "React reply: #{signal.label} is live", revision: socket.assigns.server_revision},
     socket}
  end

  def handle_event("showcase-react-action", %{"action" => action}, socket) do
    {:noreply, socket |> bump_revision() |> log_event("React action #{action}", "sky")}
  end

  def handle_event("showcase-vue-select", %{"signal" => signal_id}, socket) do
    signal = signal_by_id(signal_id)

    socket =
      socket
      |> assign(:active_signal, signal)
      |> bump_revision()
      |> log_event("Vue selected #{signal.label}", "emerald")

    {:noreply, socket}
  end

  def handle_event("showcase-native-validate", %{"showcase" => params}, socket) do
    errors = native_errors(params)
    {:noreply, assign(socket, :native_form, native_form(params, errors))}
  end

  def handle_event("showcase-native-create", %{"showcase" => params}, socket) do
    errors = native_errors(params)

    if errors == [] do
      socket =
        socket
        |> assign(:native_form, native_form(%{"name" => ""}))
        |> bump_revision()
        |> log_event("Native LiveView form captured #{params["name"]}", "violet")

      {:noreply, socket}
    else
      {:noreply, assign(socket, :native_form, native_form(params, errors))}
    end
  end

  attr :features, :list, required: true
  attr :active, :string, default: nil

  defp site_header(assigns) do
    ~H"""
    <header class="border-b border-zinc-200 bg-white">
      <div class="mx-auto flex max-w-7xl flex-col gap-4 px-5 py-5 lg:flex-row lg:items-center lg:justify-between lg:px-8">
        <.link href={~p"/"} class="flex items-center gap-3">
          <img src={~p"/images/logo.svg"} alt="LiveIslands" class="h-10 w-auto" />
          <div>
            <p class="text-sm font-semibold uppercase text-zinc-500">LiveIslands</p>
            <h1 class="text-xl font-bold">Phoenix islands for React and Vue</h1>
          </div>
        </.link>

        <nav class="grid gap-2 text-sm font-semibold sm:grid-cols-2 lg:flex lg:flex-wrap lg:justify-end">
          <.link
            :for={feature <- @features}
            href={feature_path(feature)}
            class={[
              "rounded-md border px-3 py-2 text-center transition lg:text-left",
              if(@active == feature.id,
                do: "border-zinc-950 bg-zinc-950 text-white",
                else: "border-zinc-200 bg-white text-zinc-700 hover:border-zinc-400"
              )
            ]}
          >
            {feature.number}. {feature.title}
          </.link>
        </nav>
      </div>
    </header>
    """
  end

  attr :features, :list, required: true

  defp overview(assigns) do
    ~H"""
    <section data-testid="showcase-home" class="relative isolate overflow-hidden bg-white">
      <div class="showcase-grid absolute inset-0 opacity-70"></div>
      <div class="relative mx-auto grid max-w-7xl gap-10 px-5 py-10 lg:grid-cols-[minmax(0,0.95fr)_minmax(420px,1.05fr)] lg:px-8 lg:py-14">
        <div class="grid content-between gap-8">
          <div>
            <p class="text-sm font-semibold uppercase text-zinc-500">Feature map</p>
            <h2 class="mt-4 max-w-3xl text-4xl font-bold leading-[1.05] md:text-6xl">
              One capability per page. One proof per block.
            </h2>
            <p class="mt-6 max-w-2xl text-base leading-7 text-zinc-600 md:text-lg md:leading-8">
              The demo site is now a map instead of a maze. Start with a capability,
              inspect the exact island contract, then jump to the benchmark or Todo
              app when you want the full workflow.
            </p>
          </div>

          <div class="grid gap-3 sm:grid-cols-3">
            <.summary_stat label="Frameworks" value="React + Vue" />
            <.summary_stat label="Hydration" value="load / visible" />
            <.summary_stat label="Server modes" value="SSR / deferred" />
          </div>
        </div>

        <div data-testid="feature-map" class="grid gap-3">
          <.feature_card :for={feature <- @features} feature={feature} />
        </div>
      </div>
    </section>

    <section class="mx-auto grid max-w-7xl gap-4 px-5 py-8 lg:grid-cols-3 lg:px-8">
      <.external_route_card title="Complex app" href={~p"/todo"} body="A full Todo cockpit that mimics LiveView workflows with React and Vue islands." />
      <.external_route_card title="Benchmark route" href={~p"/benchmarks"} body="PDF.js, KaTeX, SSR, lazy chunks, and release artifact measurements." />
      <.external_route_card title="Zero-JS route" href={~p"/server-only"} body="The strict route that proves React and Vue SSR without client JavaScript." />
    </section>
    """
  end

  attr :feature, :map, required: true

  defp feature_card(assigns) do
    ~H"""
    <.link
      href={feature_path(@feature)}
      data-testid={"feature-card-#{@feature.id}"}
      class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-zinc-400 hover:shadow-md"
    >
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-sm font-semibold uppercase text-zinc-500">Feature {@feature.number}</p>
          <h3 class="mt-1 text-2xl font-bold text-zinc-950">{@feature.title}</h3>
        </div>
        <span class={["rounded-md px-2 py-1 text-xs font-semibold", feature_tone(@feature.id)]}>
          open
        </span>
      </div>
      <p class="mt-3 text-sm leading-6 text-zinc-600">{@feature.short}</p>
      <div class="mt-4 flex flex-wrap gap-2">
        <span
          :for={tag <- @feature.tags}
          class="rounded-md border border-zinc-200 bg-zinc-50 px-2 py-1 text-xs font-semibold text-zinc-600"
        >
          {tag}
        </span>
      </div>
    </.link>
    """
  end

  attr :feature, :map, required: true
  attr :features, :list, required: true
  attr :active_signal, :map, required: true
  attr :event_count, :integer, required: true
  attr :metrics, :map, required: true
  attr :native_form, :any, required: true
  attr :proof_metrics, :list, required: true
  attr :server_revision, :integer, required: true
  attr :signals, :list, required: true
  attr :socket, :any, required: true
  attr :streams, :map, required: true

  defp feature_page(assigns) do
    ~H"""
    <section
      data-testid={"feature-page-#{@feature.id}"}
      class="border-b border-zinc-200 bg-white"
    >
      <div class="mx-auto grid max-w-7xl gap-8 px-5 py-8 lg:grid-cols-[minmax(0,1fr)_360px] lg:px-8 lg:py-10">
        <div>
          <.link href={~p"/"} class="text-sm font-semibold text-zinc-500 hover:text-zinc-950">
            All features
          </.link>
          <p class="mt-6 text-sm font-semibold uppercase text-zinc-500">Feature {@feature.number}</p>
          <h2 class="mt-3 max-w-4xl text-4xl font-bold leading-[1.05] md:text-6xl">
            {@feature.title}
          </h2>
          <p class="mt-5 max-w-3xl text-base leading-7 text-zinc-600 md:text-lg md:leading-8">
            {@feature.body}
          </p>
          <div class="mt-6 flex flex-wrap gap-2">
            <span
              :for={tag <- @feature.tags}
              class="rounded-md border border-zinc-200 bg-zinc-50 px-3 py-1 text-sm font-semibold text-zinc-700"
            >
              {tag}
            </span>
          </div>
        </div>

        <aside class="rounded-md border border-zinc-200 bg-zinc-50 p-5">
          <p class="text-sm font-semibold uppercase text-zinc-500">Proof on this page</p>
          <ul class="mt-4 grid gap-3 text-sm leading-6 text-zinc-700">
            <li :for={item <- @feature.proof} class="flex gap-3">
              <span class="mt-2 h-2 w-2 shrink-0 rounded-full bg-zinc-950"></span>
              <span>{item}</span>
            </li>
          </ul>
        </aside>
      </div>
    </section>

    <.feature_body
      feature={@feature}
      active_signal={@active_signal}
      event_count={@event_count}
      metrics={@metrics}
      native_form={@native_form}
      proof_metrics={@proof_metrics}
      server_revision={@server_revision}
      signals={@signals}
      socket={@socket}
      streams={@streams}
    />
    """
  end

  attr :feature, :map, required: true
  attr :active_signal, :map, required: true
  attr :event_count, :integer, required: true
  attr :metrics, :map, required: true
  attr :native_form, :any, required: true
  attr :proof_metrics, :list, required: true
  attr :server_revision, :integer, required: true
  attr :signals, :list, required: true
  attr :socket, :any, required: true
  attr :streams, :map, required: true

  defp feature_body(%{feature: %{id: "react-vue"}} = assigns) do
    ~H"""
    <section data-testid="feature-block-react-vue" class="mx-auto grid max-w-7xl gap-5 px-5 py-8 lg:grid-cols-[320px_minmax(0,1fr)] lg:px-8">
      <.live_state_panel active_signal={@active_signal} event_count={@event_count} metrics={@metrics} streams={@streams} />

      <div class="grid gap-5 xl:grid-cols-2">
        <.react
          id="feature_react_command"
          name="ShowcaseCommand"
          socket={@socket}
          metrics={@metrics}
          signals={@signals}
          activeSignal={@active_signal}
          revision={@server_revision}
          ssr={true}
          client={:load}
          prefetch={:load}
        />

        <.vue
          id="feature_vue_board"
          v-component="showcase-vue-board"
          v-socket={@socket}
          signals={@signals}
          active={@active_signal.id}
          metrics={@metrics}
          revision={@server_revision}
          v-ssr={true}
          client={:load}
          prefetch={:none}
          v-on:select={JS.push("showcase-vue-select")}
        />
      </div>
    </section>
    """
  end

  defp feature_body(%{feature: %{id: "ssr-static"}} = assigns) do
    ~H"""
    <section data-testid="feature-block-ssr-static" class="mx-auto max-w-7xl px-5 py-8 lg:px-8">
      <div class="grid gap-5 lg:grid-cols-2">
        <.react_server
          id="feature_react_server"
          name="ShowcaseProof"
          testId="showcase-react-server-proof"
          framework="React"
          mode="server-only"
          title="React server HTML"
          body="Rendered by the SSR adapter and shipped without a client hook."
          metrics={@proof_metrics}
        />
        <.vue_server
          id="feature_vue_server"
          v-component="showcase-vue-proof"
          testid="showcase-vue-server-proof"
          framework="Vue"
          mode="server-only"
          title="Vue server HTML"
          body="Rendered by the same island contract and left static."
          metrics={@proof_metrics}
        />
      </div>

      <div class="mt-5 grid gap-3 md:grid-cols-3">
        <.summary_stat label="React hook" value="none" />
        <.summary_stat label="Vue hook" value="none" />
        <.summary_stat label="Hydrated islands" value="0" />
      </div>
    </section>
    """
  end

  defp feature_body(%{feature: %{id: "lazy-deferred"}} = assigns) do
    ~H"""
    <section data-testid="feature-block-lazy-deferred" class="mx-auto max-w-7xl px-5 py-8 lg:px-8">
      <div class="grid gap-5 lg:grid-cols-2">
        <.react_server
          id="feature_react_deferred"
          name="ShowcaseProof"
          testId="showcase-react-deferred-proof"
          framework="React"
          mode="deferred"
          title="Deferred React HTML"
          body="The initial response carries the fallback; the final HTML arrives after the shell."
          metrics={@proof_metrics}
          defer={true}
          defer_timeout={5000}
          defer_cache_control="public, max-age=45"
        >
          <:fallback>
            <.deferred_fallback testid="showcase-react-deferred-fallback" />
          </:fallback>
        </.react_server>

        <.vue_server
          id="feature_vue_deferred"
          v-component="showcase-vue-proof"
          testid="showcase-vue-deferred-proof"
          framework="Vue"
          mode="deferred"
          title="Deferred Vue HTML"
          body="Vue uses the same deferred server-island fetch path."
          metrics={@proof_metrics}
          defer={true}
          defer_timeout={5000}
          defer_cache_control="public, max-age=45"
        >
          <:fallback>
            <.deferred_fallback testid="showcase-vue-deferred-fallback" />
          </:fallback>
        </.vue_server>
      </div>

      <div class="mt-8 rounded-md border border-zinc-200 bg-white p-5 shadow-sm">
        <p class="text-sm font-semibold uppercase text-zinc-500">Visible hydration target</p>
        <h3 class="mt-1 text-2xl font-bold">Scroll to hydrate Vue</h3>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-zinc-600">
          The next island is SSR HTML at first. The Vue runtime mounts it only
          when this block enters the viewport.
        </p>
      </div>

      <div class="grid min-h-[85vh] content-end pt-8">
        <.vue
          id="feature_lazy_vue_board"
          v-component="showcase-vue-board"
          v-socket={@socket}
          signals={@signals}
          active={@active_signal.id}
          metrics={@metrics}
          revision={@server_revision}
          v-ssr={true}
          client={:visible}
          prefetch={:none}
          v-on:select={JS.push("showcase-vue-select")}
        />
      </div>
    </section>
    """
  end

  defp feature_body(%{feature: %{id: "liveview-events"}} = assigns) do
    ~H"""
    <section data-testid="feature-block-liveview-events" class="mx-auto grid max-w-7xl gap-5 px-5 py-8 lg:grid-cols-[380px_minmax(0,1fr)] lg:px-8">
      <div class="grid gap-5">
        <.native_form_panel native_form={@native_form} />
        <.live_state_panel active_signal={@active_signal} event_count={@event_count} metrics={@metrics} streams={@streams} />
      </div>

      <.react
        id="feature_events_react_command"
        name="ShowcaseCommand"
        socket={@socket}
        metrics={@metrics}
        signals={@signals}
        activeSignal={@active_signal}
        revision={@server_revision}
        ssr={true}
        client={:load}
        prefetch={:load}
      />
    </section>
    """
  end

  defp feature_body(%{feature: %{id: "benchmarks"}} = assigns) do
    ~H"""
    <section data-testid="feature-block-benchmarks" class="mx-auto max-w-7xl px-5 py-8 lg:px-8">
      <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div class="rounded-md border border-zinc-200 bg-white p-6 shadow-sm">
          <p class="text-sm font-semibold uppercase text-zinc-500">Release gate</p>
          <h3 class="mt-2 text-3xl font-bold">Benchmarks stay on their own route.</h3>
          <p class="mt-4 max-w-3xl text-sm leading-6 text-zinc-600">
            The benchmark route is intentionally separate from the marketing or
            capability pages. It exercises PDF.js, KaTeX, deferred server islands,
            route navigation, intent prefetch, online browser measurement, and
            release artifacts without hiding the cost inside the default page.
          </p>
          <div class="mt-6 flex flex-wrap gap-3">
            <.link href={~p"/benchmarks"} data-testid="feature-open-benchmarks" class="rounded-md bg-zinc-950 px-4 py-3 text-sm font-semibold text-white hover:bg-zinc-800">
              Open benchmark lab
            </.link>
            <.link href={~p"/todo"} class="rounded-md border border-zinc-300 bg-white px-4 py-3 text-sm font-semibold text-zinc-900 hover:border-zinc-400">
              Open complex Todo app
            </.link>
          </div>
        </div>

        <div class="grid gap-3">
          <.summary_stat label="Home budget" value="lightweight" />
          <.summary_stat label="Heavy chunks" value="intent only" />
          <.summary_stat label="Release proof" value="artifact trend" />
        </div>
      </div>
    </section>
    """
  end

  attr :active_signal, :map, required: true
  attr :event_count, :integer, required: true
  attr :metrics, :map, required: true
  attr :streams, :map, required: true

  defp live_state_panel(assigns) do
    ~H"""
    <aside class="rounded-md border border-zinc-200 bg-zinc-950 p-5 text-white shadow-sm">
      <p class="text-sm font-semibold uppercase text-zinc-400">LiveView state</p>
      <h3 data-testid="showcase-active-signal" class="mt-1 text-2xl font-bold">
        {@active_signal.label}
      </h3>

      <div class="mt-5 grid grid-cols-3 gap-2">
        <.mini_stat label="Events" value={@event_count} />
        <.mini_stat label="React" value={@metrics.react} />
        <.mini_stat label="Vue" value={@metrics.vue} />
      </div>

      <div id="showcase-events" phx-update="stream" class="mt-5 grid gap-2">
        <div
          :for={{dom_id, event} <- @streams.events}
          id={dom_id}
          class={[
            "rounded-md border px-3 py-2 text-sm",
            event_tone(event.tone)
          ]}
        >
          <span class="font-semibold">{event.at}</span>
          <span class="ml-2">{event.label}</span>
        </div>
      </div>
    </aside>
    """
  end

  attr :native_form, :any, required: true

  defp native_form_panel(assigns) do
    ~H"""
    <div class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-sm font-semibold uppercase text-zinc-500">Native LiveView</p>
          <h3 class="mt-1 text-xl font-bold">Form and JS command</h3>
        </div>
        <button
          type="button"
          data-testid="showcase-js-toggle"
          phx-click={JS.toggle(to: "#showcase-js-panel")}
          class="rounded-md border border-zinc-300 px-3 py-2 text-sm font-semibold hover:border-zinc-400"
        >
          Toggle
        </button>
      </div>

      <div id="showcase-js-panel" class="mt-4 hidden rounded-md bg-zinc-50 p-3 text-sm text-zinc-600">
        Phoenix.LiveView.JS toggled this panel without a client island.
      </div>

      <.form
        for={@native_form}
        phx-change="showcase-native-validate"
        phx-submit="showcase-native-create"
        data-testid="showcase-native-form"
        class="mt-5 grid gap-3"
      >
        <label class="grid gap-1">
          <span class="text-sm font-semibold text-zinc-700">Project signal</span>
          <input
            name="showcase[name]"
            value={@native_form[:name].value}
            data-testid="showcase-native-name"
            class="rounded-md border border-zinc-300 px-3 py-2 outline-none transition focus:border-zinc-950"
          />
        </label>
        <p data-testid="showcase-native-error" class="min-h-5 text-sm font-medium text-rose-700">
          {native_error(@native_form, :name)}
        </p>
        <button
          type="submit"
          data-testid="showcase-native-submit"
          class="rounded-md bg-zinc-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-zinc-800"
        >
          Commit signal
        </button>
      </.form>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp summary_stat(assigns) do
    ~H"""
    <div class="rounded-md border border-zinc-200 bg-white/90 p-4 shadow-sm">
      <dt class="text-xs font-semibold uppercase text-zinc-500">{@label}</dt>
      <dd class="mt-2 text-2xl font-bold text-zinc-950">{@value}</dd>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp mini_stat(assigns) do
    ~H"""
    <div class="rounded-md border border-white/10 bg-white/5 p-3 text-center">
      <div class="text-2xl font-bold">{@value}</div>
      <div class="text-xs font-semibold uppercase text-zinc-400">{@label}</div>
    </div>
    """
  end

  attr :testid, :string, required: true

  defp deferred_fallback(assigns) do
    ~H"""
    <section data-testid={@testid} class="showcase-card animate-pulse rounded-md border border-zinc-200 bg-white p-5">
      <div class="h-3 w-24 rounded bg-zinc-200"></div>
      <div class="mt-5 h-20 rounded bg-zinc-100"></div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :href, :string, required: true

  defp external_route_card(assigns) do
    ~H"""
    <.link href={@href} class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-zinc-300 hover:shadow-md">
      <h3 class="text-lg font-bold text-zinc-950">{@title}</h3>
      <p class="mt-2 text-sm leading-6 text-zinc-600">{@body}</p>
      <div class="mt-5 text-sm font-semibold text-zinc-950">Open route</div>
    </.link>
    """
  end

  defp native_form(params, errors \\ []) do
    to_form(params, as: :showcase, errors: errors, action: :validate)
  end

  defp native_errors(params) do
    name = String.trim(params["name"] || "")

    cond do
      name == "" -> [name: {"is required", []}]
      String.length(name) < 4 -> [name: {"use at least 4 characters", []}]
      true -> []
    end
  end

  defp native_error(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map_join(", ", fn {message, _opts} -> message end)
  end

  defp bump_revision(socket) do
    update(socket, :server_revision, &(&1 + 1))
  end

  defp log_event(socket, label, tone) do
    socket
    |> update(:event_count, &(&1 + 1))
    |> stream_insert(:events, %{
      id: "event-#{System.unique_integer([:positive])}",
      label: label,
      tone: tone,
      at: Calendar.strftime(Time.utc_now(), "%H:%M:%S")
    }, at: 0)
  end

  defp feature_by_id(nil), do: nil
  defp feature_by_id(id), do: Enum.find(@features, &(&1.id == id))

  defp feature_path(feature), do: "/features/#{feature.id}"

  defp page_title(nil), do: "LiveIslands"
  defp page_title(feature), do: "#{feature.title} - LiveIslands"

  defp signals do
    [
      %{id: "edge", label: "Vue lane: edge UI", score: 97, tone: "emerald"},
      %{id: "react", label: "React lane: command UI", score: 96, tone: "sky"},
      %{id: "ssr", label: "SSR lane: static HTML", score: 99, tone: "violet"},
      %{id: "lazy", label: "Lazy lane: intent chunks", score: 94, tone: "amber"}
    ]
  end

  defp signal_by_id(id), do: Enum.find(signals(), hd(signals()), &(&1.id == id))

  defp proof_metrics do
    [
      %{label: "HTML", value: "SSR"},
      %{label: "Hook", value: "none"},
      %{label: "Chunk", value: "lazy"}
    ]
  end

  defp initial_events do
    [
      %{id: "event-1", label: "LiveView shell rendered route", tone: "zinc", at: "09:00:00"},
      %{id: "event-2", label: "React island registered command lane", tone: "sky", at: "09:00:01"},
      %{id: "event-3", label: "Vue island registered signal lane", tone: "emerald", at: "09:00:02"}
    ]
  end

  defp feature_tone("react-vue"), do: "bg-sky-50 text-sky-700"
  defp feature_tone("ssr-static"), do: "bg-violet-50 text-violet-700"
  defp feature_tone("lazy-deferred"), do: "bg-amber-50 text-amber-800"
  defp feature_tone("liveview-events"), do: "bg-emerald-50 text-emerald-700"
  defp feature_tone("benchmarks"), do: "bg-zinc-100 text-zinc-700"
  defp feature_tone(_), do: "bg-zinc-100 text-zinc-700"

  defp event_tone("sky"), do: "border-sky-200 bg-sky-50 text-sky-800"
  defp event_tone("emerald"), do: "border-emerald-200 bg-emerald-50 text-emerald-800"
  defp event_tone("violet"), do: "border-violet-200 bg-violet-50 text-violet-800"
  defp event_tone(_), do: "border-zinc-200 bg-zinc-50 text-zinc-700"
end
