defmodule LiveIslandsExamplesWeb.LiveShowcase do
  use Phoenix.LiveView, layout: false

  import LiveIslands

  alias Phoenix.LiveView.JS

  use Phoenix.VerifiedRoutes,
    endpoint: LiveIslandsExamplesWeb.Endpoint,
    router: LiveIslandsExamplesWeb.Router,
    statics: LiveIslandsExamplesWeb.static_paths()

  def render(assigns) do
    ~H"""
    <main
      data-live-islands-page="/"
      data-testid="showcase-page"
      class="showcase-shell min-h-screen bg-[#f5f7fb] text-zinc-950"
    >
      <section class="relative isolate overflow-hidden border-b border-zinc-200 bg-white">
        <div class="showcase-grid absolute inset-0 opacity-70"></div>
        <div class="relative mx-auto grid max-w-7xl gap-10 px-5 py-8 lg:grid-cols-[minmax(0,1fr)_420px] lg:px-8 lg:py-12">
          <div class="grid content-between gap-10">
            <nav class="flex flex-wrap items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <img src={~p"/images/logo.svg"} alt="LiveIslands" class="h-10 w-auto" />
                <div>
                  <p class="text-sm font-semibold uppercase text-zinc-500">LiveIslands</p>
                  <h1 class="text-xl font-bold">React + Vue islands for LiveView</h1>
                </div>
              </div>
              <div class="flex flex-wrap gap-2 text-sm font-semibold">
                <span class="rounded-md border border-sky-200 bg-sky-50 px-3 py-1 text-sky-700">React</span>
                <span class="rounded-md border border-emerald-200 bg-emerald-50 px-3 py-1 text-emerald-700">Vue</span>
                <span class="rounded-md border border-violet-200 bg-violet-50 px-3 py-1 text-violet-700">SSR</span>
                <span class="rounded-md border border-amber-200 bg-amber-50 px-3 py-1 text-amber-800">Lazy</span>
              </div>
            </nav>

            <div class="max-w-4xl">
              <p class="text-sm font-semibold uppercase text-zinc-500">Default demo site</p>
              <h2 class="mt-4 max-w-4xl text-4xl font-bold leading-[1.05] text-zinc-950 md:text-6xl lg:text-7xl">
                One LiveView page, two frontend runtimes, measured at the island boundary.
              </h2>
              <p class="mt-6 max-w-2xl text-base leading-7 text-zinc-600 md:text-lg md:leading-8">
                The shell is LiveView. React and Vue both render, hydrate, defer,
                prefetch, reply to events, and leave server-only HTML behind when
                the page asks them to stay static.
              </p>
              <div class="mt-8 flex flex-wrap gap-3">
                <.link
                  href={~p"/todo"}
                  class="rounded-md bg-zinc-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-zinc-800"
                >
                  Open Todo cockpit
                </.link>
                <.link
                  navigate={~p"/benchmarks"}
                  class="rounded-md border border-zinc-300 bg-white px-4 py-3 text-sm font-semibold text-zinc-900 transition hover:border-zinc-400"
                >
                  View benchmarks
                </.link>
              </div>
            </div>

            <dl class="grid gap-3 sm:grid-cols-4">
              <.metric label="Initial frameworks" value="2" tone="sky" />
              <.metric label="Hydration modes" value="5" tone="emerald" />
              <.metric label="Server proofs" value="4" tone="violet" />
              <.metric label="Benchmark schema" value="v9" tone="amber" />
            </dl>
          </div>

          <aside class="grid content-start gap-4">
            <div class="rounded-md border border-zinc-200 bg-zinc-950 p-5 text-white shadow-sm">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <p class="text-sm font-semibold uppercase text-zinc-400">LiveView state</p>
                  <h3 data-testid="showcase-active-signal" class="mt-1 text-2xl font-bold">
                    {@active_signal.label}
                  </h3>
                </div>
                <span class="rounded-md bg-white px-3 py-1 text-sm font-semibold text-zinc-950">
                  rev {@server_revision}
                </span>
              </div>
              <div class="mt-5 grid grid-cols-3 gap-2">
                <.mini_stat label="Events" value={@event_count} />
                <.mini_stat label="React" value={@metrics.react} />
                <.mini_stat label="Vue" value={@metrics.vue} />
              </div>
            </div>

            <div class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold uppercase text-zinc-500">Native LiveView</p>
                  <h3 class="mt-1 text-xl font-bold">Server stream</h3>
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
              <div id="showcase-events" phx-update="stream" class="mt-4 grid gap-2">
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
            </div>
          </aside>
        </div>
      </section>

      <section class="mx-auto grid max-w-7xl gap-5 px-5 py-8 lg:grid-cols-2 lg:px-8">
        <.react
          id="showcase_react_command"
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
          id="showcase_vue_board"
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
      </section>

      <section class="mx-auto grid max-w-7xl gap-5 px-5 pb-8 lg:grid-cols-4 lg:px-8">
        <.react_server
          id="showcase_react_server"
          name="ShowcaseProof"
          testId="showcase-react-server-proof"
          framework="React"
          mode="server-only"
          title="Static product summary"
          body="Rendered through SSR and shipped without a LiveView hook."
          metrics={@proof_metrics}
        />
        <.vue_server
          id="showcase_vue_server"
          v-component="showcase-vue-proof"
          testid="showcase-vue-server-proof"
          framework="Vue"
          mode="server-only"
          title="Design signal panel"
          body="Vue SSR rendered the card and left it static."
          metrics={@proof_metrics}
        />
        <.react_server
          id="showcase_react_deferred"
          name="ShowcaseProof"
          testId="showcase-react-deferred-proof"
          framework="React"
          mode="deferred"
          title="Deferred React insight"
          body="The shell shows a fallback, then fetches this SSR HTML."
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
          id="showcase_vue_deferred"
          v-component="showcase-vue-proof"
          testid="showcase-vue-deferred-proof"
          framework="Vue"
          mode="deferred"
          title="Deferred Vue insight"
          body="The same deferred island contract works for Vue."
          metrics={@proof_metrics}
          defer={true}
          defer_timeout={5000}
          defer_cache_control="public, max-age=45"
        >
          <:fallback>
            <.deferred_fallback testid="showcase-vue-deferred-fallback" />
          </:fallback>
        </.vue_server>
      </section>

      <section class="mx-auto grid max-w-7xl gap-5 px-5 pb-12 lg:grid-cols-[380px_minmax(0,1fr)] lg:px-8">
        <div class="rounded-md border border-zinc-200 bg-white p-5 shadow-sm">
          <p class="text-sm font-semibold uppercase text-zinc-500">LiveView form</p>
          <h3 class="mt-1 text-xl font-bold">Native validation</h3>
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

        <div class="grid gap-3 md:grid-cols-3">
          <.route_card title="Complex app" href={~p"/todo"} body="LiveView source of truth with React workspace and Vue rhythm." />
          <.route_card title="Benchmark lab" href={~p"/benchmarks"} body="KaTeX, PDF.js, SSR, deferred fetches, and release artifacts." />
          <.route_card title="Zero-JS route" href={~p"/server-only"} body="React and Vue render on the server without booting LiveSocket." />
        </div>
      </section>
    </main>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> LiveIslands.put_asset_profile(:islands)
      |> assign(:page_title, "LiveIslands")
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

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, default: "sky"

  defp metric(assigns) do
    ~H"""
    <div class={["rounded-md border bg-white/90 p-4 shadow-sm", metric_tone(@tone)]}>
      <dt class="text-xs font-semibold uppercase text-zinc-500">{@label}</dt>
      <dd class="mt-2 text-3xl font-bold text-zinc-950">{@value}</dd>
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

  defp route_card(assigns) do
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
      %{id: "event-1", label: "LiveView shell rendered root page", tone: "zinc", at: "09:00:00"},
      %{id: "event-2", label: "React island registered command lane", tone: "sky", at: "09:00:01"},
      %{id: "event-3", label: "Vue island registered signal lane", tone: "emerald", at: "09:00:02"}
    ]
  end

  defp metric_tone("sky"), do: "border-sky-200"
  defp metric_tone("emerald"), do: "border-emerald-200"
  defp metric_tone("violet"), do: "border-violet-200"
  defp metric_tone("amber"), do: "border-amber-200"
  defp metric_tone(_), do: "border-zinc-200"

  defp event_tone("sky"), do: "border-sky-200 bg-sky-50 text-sky-800"
  defp event_tone("emerald"), do: "border-emerald-200 bg-emerald-50 text-emerald-800"
  defp event_tone("violet"), do: "border-violet-200 bg-violet-50 text-violet-800"
  defp event_tone(_), do: "border-zinc-200 bg-zinc-50 text-zinc-700"
end
