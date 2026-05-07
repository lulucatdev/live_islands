defmodule LiveIslandsExamplesWeb.LiveTodoApp do
  use Phoenix.LiveView, layout: {LiveIslandsExamplesWeb.Layouts, :todo}

  use Phoenix.VerifiedRoutes,
    endpoint: LiveIslandsExamplesWeb.Endpoint,
    router: LiveIslandsExamplesWeb.Router,
    statics: LiveIslandsExamplesWeb.static_paths()

  import LiveIslands

  alias Phoenix.LiveView.JS

  @lanes [
    %{id: "backlog", title: "Backlog", accent: "slate"},
    %{id: "today", title: "Today", accent: "sky"},
    %{id: "doing", title: "Doing", accent: "amber"},
    %{id: "review", title: "Review", accent: "violet"},
    %{id: "done", title: "Done", accent: "emerald"}
  ]

  @priorities ~w(P0 P1 P2 P3)

  def render(assigns) do
    assigns =
      assigns
      |> assign(:lanes, @lanes)
      |> assign(:priorities, @priorities)
      |> assign(:visible_todos, visible_todos(assigns.todos, assigns.filter, assigns.search))
      |> assign(:metrics, metrics(assigns.todos, assigns.focus_sessions))

    ~H"""
    <main
      data-live-islands-page="/todo"
      data-testid="todo-demo-page"
      class="todo-demo min-h-screen overflow-hidden bg-[#f7f8fb] text-zinc-950"
    >
      <header class="sticky top-0 z-40 border-b border-zinc-200/80 bg-white/85 backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-5 py-4 lg:px-8">
          <div class="flex items-center gap-3">
            <img src={~p"/images/logo.svg"} alt="LiveIslands" class="h-9 w-auto" />
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500">
                LiveIslands demo
              </p>
              <h1 class="text-lg font-bold leading-tight">Todo Operations Cockpit</h1>
            </div>
          </div>
          <div class="hidden items-center gap-2 md:flex">
            <a
              href={~p"/capabilities"}
              class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm font-medium text-zinc-700 shadow-sm transition hover:border-zinc-300 hover:bg-zinc-50"
            >
              Capabilities
            </a>
            <a
              href={~p"/benchmarks"}
              class="rounded-md bg-zinc-950 px-3 py-2 text-sm font-medium text-white shadow-sm transition hover:bg-zinc-800"
            >
              Benchmarks
            </a>
          </div>
        </div>
      </header>

      <section class="todo-hero relative border-b border-zinc-200">
        <div class="todo-grid-overlay absolute inset-0"></div>
        <div class="relative mx-auto grid max-w-7xl gap-8 px-5 py-10 lg:grid-cols-[1.1fr_0.9fr] lg:px-8 lg:py-14">
          <div class="space-y-6">
            <div class="inline-flex items-center gap-2 rounded-full border border-zinc-200 bg-white px-3 py-1 text-sm font-medium text-zinc-700 shadow-sm">
              <span class="h-2 w-2 rounded-full bg-emerald-500"></span>
              React + Vue + SSR + lazy islands on one route
            </div>
            <div class="max-w-3xl space-y-4">
              <h2 class="text-4xl font-bold tracking-normal text-zinc-950 md:text-6xl">
                Plan the day without shipping the whole frontend at once.
              </h2>
              <p class="max-w-2xl text-lg leading-8 text-zinc-600">
                A product-grade Todo app that uses LiveView as the source of truth,
                React for the animated board, Vue for team rhythm, and server islands
                for static and deferred intelligence.
              </p>
            </div>
            <div class="grid max-w-2xl gap-3 sm:grid-cols-4">
              <.metric_pill label="Open" value={@metrics.open} tone="sky" />
              <.metric_pill label="Done" value={@metrics.done} tone="emerald" />
              <.metric_pill label="Focus" value={"#{@metrics.focus}%"} tone="violet" />
              <.metric_pill label="P0" value={@metrics.p0} tone="rose" />
            </div>
          </div>

          <div class="grid content-start gap-4">
            <.react_server
              id="todo_static_digest"
              name="TodoSsrDigest"
              tasks={@todos}
              metrics={@metrics}
              mode={@mode}
            />
            <.vue_server
              id="todo_static_rhythm"
              v-component="todo-rhythm"
              stats={@metrics}
              mode={@mode}
              readonly={true}
            />
          </div>
        </div>
      </section>

      <section class="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:grid-cols-[minmax(0,1fr)_360px] lg:px-8">
        <div
          data-testid="todo-liveview-panel"
          class="todo-card border border-zinc-200 bg-white p-5 shadow-sm"
        >
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500">
                LiveView control plane
              </p>
              <h2 class="mt-1 text-2xl font-bold text-zinc-950">Server-owned workflow</h2>
            </div>
            <div
              data-testid="todo-url-state"
              class="rounded-full border border-zinc-200 bg-zinc-50 px-3 py-1 text-sm font-medium text-zinc-700"
            >
              {url_state_label(@filter, @search, @mode)}
            </div>
          </div>

          <div class="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1fr)_280px]">
            <.form
              for={%{}}
              as={:native}
              phx-change="native-validate"
              phx-submit="native-create"
              data-testid="todo-native-form"
              class="grid gap-3 rounded-md border border-zinc-200 bg-zinc-50 p-4"
            >
              <div class="grid gap-3 md:grid-cols-[minmax(0,1fr)_150px]">
                <label class="grid gap-1">
                  <span class="text-xs font-semibold uppercase text-zinc-500">Task</span>
                  <input
                    data-testid="todo-native-title"
                    name="native[title]"
                    value={@native_form["title"]}
                    placeholder="Server validated task"
                    class={[
                      "rounded-md border bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100",
                      if(@native_errors["title"], do: "border-rose-300", else: "border-zinc-200")
                    ]}
                  />
                  <p
                    :if={@native_errors["title"]}
                    data-testid="todo-native-title-error"
                    class="text-xs font-medium text-rose-600"
                  >
                    {@native_errors["title"]}
                  </p>
                </label>
                <label class="grid gap-1">
                  <span class="text-xs font-semibold uppercase text-zinc-500">Owner</span>
                  <input
                    name="native[owner]"
                    value={@native_form["owner"]}
                    class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                  />
                </label>
              </div>
              <div class="grid gap-3 md:grid-cols-4">
                <select
                  name="native[priority]"
                  class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                >
                  <option :for={priority <- @priorities} selected={@native_form["priority"] == priority}>
                    {priority}
                  </option>
                </select>
                <select
                  name="native[lane]"
                  class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                >
                  <option :for={lane <- @lanes} value={lane.id} selected={@native_form["lane"] == lane.id}>
                    {lane.title}
                  </option>
                </select>
                <input
                  name="native[points]"
                  type="number"
                  min="1"
                  max="13"
                  value={@native_form["points"]}
                  class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm"
                />
                <button
                  data-testid="todo-native-submit"
                  type="submit"
                  class="rounded-md bg-zinc-950 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-zinc-800"
                >
                  Add
                </button>
              </div>
            </.form>

            <div class="grid content-start gap-3">
              <div class="grid gap-2 rounded-md border border-zinc-200 bg-white p-3">
                <div class="flex flex-wrap gap-2">
                  <.link
                    :for={filter <- ["all", "open", "today", "review", "done"]}
                    patch={todo_path(assigns, %{"filter" => filter})}
                    data-testid={"todo-live-filter-#{filter}"}
                    class={[
                      "rounded-md px-3 py-2 text-sm font-medium transition",
                      if(@filter == filter,
                        do: "bg-zinc-950 text-white",
                        else: "border border-zinc-200 bg-white text-zinc-700 hover:bg-zinc-50"
                      )
                    ]}
                  >
                    {labelize(filter)}
                  </.link>
                </div>
                <button
                  type="button"
                  data-testid="todo-server-cycle-filter"
                  phx-click="server-cycle-filter"
                  class="rounded-md border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm font-medium text-zinc-700 transition hover:bg-white"
                >
                  Cycle route filter
                </button>
              </div>

              <button
                type="button"
                data-testid="todo-js-inspector-toggle"
                phx-click={JS.toggle(to: "#todo-liveview-inspector")}
                class="rounded-md border border-zinc-200 bg-white px-3 py-2 text-sm font-medium text-zinc-700 shadow-sm transition hover:bg-zinc-50"
              >
                Toggle inspector
              </button>
              <div
                id="todo-liveview-inspector"
                data-testid="todo-liveview-inspector"
                class="hidden rounded-md border border-zinc-200 bg-zinc-950 p-4 text-sm text-white"
              >
                <div class="font-semibold">Server revision {@server_revision}</div>
                <div class="mt-2 text-zinc-300">Events handled {@server_event_count}</div>
                <div class="mt-2 text-zinc-300">Visible tasks {length(@visible_todos)}</div>
              </div>
            </div>
          </div>
        </div>

        <section class="todo-card border border-zinc-200 bg-white p-5 shadow-sm">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500">
                Live stream
              </p>
              <h3 class="mt-1 text-xl font-bold text-zinc-950">Activity</h3>
            </div>
            <span class="rounded-full bg-sky-50 px-3 py-1 text-sm font-semibold text-sky-700">
              {Enum.count(@streams.activity)}
            </span>
          </div>
          <ol
            id="todo-live-activity"
            data-testid="todo-live-activity"
            phx-update="stream"
            class="mt-4 grid gap-2"
          >
            <li
              :for={{dom_id, event} <- @streams.activity}
              id={dom_id}
              class="rounded-md border border-zinc-100 bg-zinc-50 px-3 py-2 text-sm"
            >
              <div class="font-medium text-zinc-800">{event.label}</div>
              <div class="mt-1 text-xs text-zinc-500">{event.at}</div>
            </li>
          </ol>
        </section>
      </section>

      <section class="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:grid-cols-[minmax(0,1fr)_340px] lg:px-8">
        <.react
          id="todo_workspace"
          name="TodoWorkspace"
          socket={@socket}
          todos={@visible_todos}
          allTodos={@todos}
          activity={@streams.activity}
          lanes={@lanes}
          metrics={@metrics}
          filter={@filter}
          search={@search}
          mode={@mode}
          ssr={false}
          client={:load}
          prefetch={:load}
        />

        <aside class="grid content-start gap-6">
          <.vue
            id="todo_rhythm_panel"
            v-component="todo-rhythm"
            v-socket={@socket}
            stats={@metrics}
            mode={@mode}
            readonly={false}
            v-ssr={false}
            client={:visible}
            prefetch={:idle}
            v-on:mode={JS.push("todo-vue-mode")}
          />

          <.react
            id="todo_focus_timer"
            name="TodoFocusTimer"
            socket={@socket}
            goal={@focus_goal}
            sessions={@focus_sessions}
            ssr={true}
            client={:visible}
            prefetch={:idle}
          />

          <.react
            id="todo_command_center"
            name="TodoCommandCenter"
            socket={@socket}
            todos={@todos}
            metrics={@metrics}
            ssr={true}
            client={:interaction}
            prefetch={:intent}
          />

          <.react_server
            id="todo_deferred_digest"
            name="TodoDeferredDigest"
            tasks={@todos}
            metrics={@metrics}
            mode={@mode}
            defer={true}
            defer_timeout={5000}
            defer_cache_control="public, max-age=45"
          >
            <:fallback>
              <section
                data-testid="todo-deferred-fallback"
                class="todo-card animate-pulse border border-zinc-200 bg-white p-5"
              >
                <div class="h-4 w-32 rounded bg-zinc-200"></div>
                <div class="mt-4 h-20 rounded bg-zinc-100"></div>
              </section>
            </:fallback>
          </.react_server>
        </aside>
      </section>
    </main>
    """
  end

  def mount(_params, _session, socket) do
    todos = seed_todos()

    socket =
      socket
      |> LiveIslands.put_asset_profile(:islands)
      |> assign(:page_title, "Todo Operations Cockpit")
      |> assign(:todos, todos)
      |> assign(:filter, "all")
      |> assign(:search, "")
      |> assign(:mode, "Launch")
      |> assign(:native_form, native_form())
      |> assign(:native_errors, %{})
      |> assign(:server_event_count, 0)
      |> assign(:server_revision, 1)
      |> assign(:focus_goal, 45)
      |> assign(:focus_sessions, 2)
      |> stream(:activity, seed_activity())

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:filter, valid_filter(params["filter"]))
      |> assign(:search, clean_search(params["search"]))
      |> assign(:mode, valid_mode(params["mode"]))
      |> update(:server_revision, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_event("todo-create", %{"title" => title} = params, socket) do
    case String.trim(title || "") do
      "" ->
        {:noreply, socket}

      clean_title ->
        todo = new_todo(clean_title, params)

        socket =
          socket
          |> update(:todos, &[todo | &1])
          |> log_activity("Created #{todo.title}", "emerald")

        {:noreply, socket}
    end
  end

  def handle_event("todo-toggle", %{"id" => id}, socket) do
    {todos, title} =
      update_todo(socket.assigns.todos, id, fn todo ->
        done? = not todo.done

        todo
        |> Map.put(:done, done?)
        |> Map.put(:lane, if(done?, do: "done", else: open_lane(todo.lane)))
        |> Map.put(:progress, if(done?, do: 100, else: min(todo.progress, 80)))
      end)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Toggled #{title}", "sky")

    {:noreply, socket}
  end

  def handle_event("todo-move", %{"id" => id, "lane" => lane}, socket) do
    lane = if lane in Enum.map(@lanes, & &1.id), do: lane, else: "today"

    {todos, title} =
      update_todo(socket.assigns.todos, id, fn todo ->
        todo
        |> Map.put(:lane, lane)
        |> Map.put(:done, lane == "done")
        |> Map.put(:progress, progress_for_lane(lane, todo.progress))
      end)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Moved #{title} to #{lane}", "violet")

    {:noreply, socket}
  end

  def handle_event("todo-priority", %{"id" => id, "priority" => priority}, socket) do
    priority = if priority in @priorities, do: priority, else: "P2"

    {todos, title} =
      update_todo(socket.assigns.todos, id, fn todo ->
        Map.put(todo, :priority, priority)
      end)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Reprioritized #{title} to #{priority}", "amber")

    {:noreply, socket}
  end

  def handle_event("todo-delete", %{"id" => id}, socket) do
    {todo, todos} = pop_todo(socket.assigns.todos, id)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Removed #{todo.title}", "rose")

    {:noreply, socket}
  end

  def handle_event("todo-filter", params, socket) do
    filter = valid_filter(Map.get(params, "filter", socket.assigns.filter))
    search = clean_search(Map.get(params, "search", socket.assigns.search))

    socket =
      socket
      |> log_activity("Patched route filter to #{filter}", "sky")
      |> push_patch(to: todo_path(socket, %{"filter" => filter, "search" => search}))

    {:noreply, socket}
  end

  def handle_event("todo-clear-done", _params, socket) do
    todos = Enum.reject(socket.assigns.todos, & &1.done)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Cleared completed tasks", "rose")

    {:noreply, socket}
  end

  def handle_event("todo-vue-mode", %{"mode" => mode}, socket) do
    mode = valid_mode(mode)

    socket =
      socket
      |> log_activity("Vue rhythm switched to #{mode}", "emerald")
      |> push_patch(to: todo_path(socket, %{"mode" => mode}))

    {:noreply, socket}
  end

  def handle_event("native-validate", %{"native" => params}, socket) do
    {:noreply, assign(socket, native_form: normalize_native_form(params), native_errors: native_errors(params))}
  end

  def handle_event("native-create", %{"native" => params}, socket) do
    errors = native_errors(params)

    if map_size(errors) > 0 do
      socket =
        socket
        |> assign(native_form: normalize_native_form(params), native_errors: errors)
        |> log_activity("Rejected server form input", "rose")

      {:noreply, socket}
    else
      todo =
        params["title"]
        |> String.trim()
        |> new_todo(native_todo_params(params))

      socket =
        socket
        |> assign(:native_form, native_form())
        |> assign(:native_errors, %{})
        |> update(:todos, &[todo | &1])
        |> log_activity("LiveView form created #{todo.title}", "emerald")

      {:noreply, socket}
    end
  end

  def handle_event("server-cycle-filter", _params, socket) do
    filter = next_filter(socket.assigns.filter)

    socket =
      socket
      |> log_activity("Server cycled filter to #{filter}", "violet")
      |> push_patch(to: todo_path(socket, %{"filter" => filter}))

    {:noreply, socket}
  end

  def handle_event("focus-started", _params, socket) do
    {:noreply, log_activity(socket, "Started a focus block", "sky")}
  end

  def handle_event("focus-complete", _params, socket) do
    socket =
      socket
      |> update(:focus_sessions, &(&1 + 1))
      |> log_activity("Completed a focus block", "emerald")

    {:noreply, socket}
  end

  def handle_event("command-action", %{"action" => "plan-today"}, socket) do
    todos =
      Enum.map(socket.assigns.todos, fn
        %{lane: "backlog", done: false} = todo -> %{todo | lane: "today", progress: 30}
        todo -> todo
      end)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Promoted backlog into today's plan", "violet")
      |> push_patch(to: todo_path(socket, %{"mode" => "Plan"}))

    {:noreply, socket}
  end

  def handle_event("command-action", %{"action" => "clear-done"}, socket) do
    handle_event("todo-clear-done", %{}, socket)
  end

  def handle_event("command-action", %{"action" => "ship-review"}, socket) do
    todos =
      Enum.map(socket.assigns.todos, fn
        %{lane: "review"} = todo -> %{todo | lane: "done", done: true, progress: 100}
        todo -> todo
      end)

    socket =
      socket
      |> assign(:todos, todos)
      |> log_activity("Shipped review lane", "emerald")
      |> push_patch(to: todo_path(socket, %{"mode" => "Ship"}))

    {:noreply, socket}
  end

  def handle_event("todo-suggest", _params, socket) do
    next =
      socket.assigns.todos
      |> Enum.reject(& &1.done)
      |> Enum.sort_by(&{priority_rank(&1.priority), &1.due})
      |> List.first()

    reply =
      if next do
        %{
          headline: "Focus #{next.title}",
          confidence: 92,
          steps: [
            "Move #{next.owner} into a 45 minute block",
            "Finish the #{next.lane} lane acceptance note",
            "Ask for review before #{next.due}"
          ]
        }
      else
        %{
          headline: "Everything is clear",
          confidence: 100,
          steps: ["Archive the plan", "Write a release note", "Take the next brief"]
        }
      end

    {:reply, reply, log_activity(socket, "Generated an event-reply plan", "sky")}
  end

  defp metric_pill(assigns) do
    ~H"""
    <div class={[
      "rounded-md border bg-white/85 p-4 shadow-sm",
      pill_border(@tone)
    ]}>
      <div class="text-xs font-semibold uppercase tracking-wide text-zinc-500">{@label}</div>
      <div class="mt-2 text-2xl font-bold text-zinc-950">{@value}</div>
    </div>
    """
  end

  defp pill_border("emerald"), do: "border-emerald-200"
  defp pill_border("violet"), do: "border-violet-200"
  defp pill_border("rose"), do: "border-rose-200"
  defp pill_border(_tone), do: "border-sky-200"

  defp native_form do
    %{
      "title" => "",
      "owner" => "Mira",
      "priority" => "P2",
      "lane" => "today",
      "points" => "3"
    }
  end

  defp normalize_native_form(params) do
    Map.merge(native_form(), Map.take(params, ["title", "owner", "priority", "lane", "points"]))
  end

  defp native_errors(params) do
    params = normalize_native_form(params)

    %{}
    |> maybe_error(
      "title",
      String.length(String.trim(params["title"])) < 4,
      "Use at least 4 characters"
    )
    |> maybe_error("owner", String.trim(params["owner"]) == "", "Choose an owner")
  end

  defp maybe_error(errors, key, true, message), do: Map.put(errors, key, message)
  defp maybe_error(errors, _key, false, _message), do: errors

  defp native_todo_params(params) do
    params
    |> normalize_native_form()
    |> Map.merge(%{
      "body" => "Created by a native LiveView form with server validation.",
      "due" => "17:30",
      "tags" => "liveview,native"
    })
  end

  defp todo_path(%{assigns: assigns}, updates), do: todo_path(assigns, updates)

  defp todo_path(assigns, updates) do
    query =
      %{
        "filter" => Map.get(assigns, :filter, "all"),
        "search" => Map.get(assigns, :search, ""),
        "mode" => Map.get(assigns, :mode, "Launch")
      }
      |> Map.merge(updates)
      |> Enum.reject(fn
        {"filter", "all"} -> true
        {"search", ""} -> true
        {"mode", "Launch"} -> true
        {_key, nil} -> true
        {_key, ""} -> true
        _entry -> false
      end)
      |> Map.new()

    if map_size(query) == 0 do
      ~p"/todo"
    else
      ~p"/todo?#{query}"
    end
  end

  defp url_state_label(filter, search, mode) do
    search_label = if search == "", do: "no search", else: "search: #{search}"
    "#{labelize(filter)} / #{mode} / #{search_label}"
  end

  defp labelize(value) do
    value
    |> to_string()
    |> String.replace("-", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp valid_filter(filter) do
    filter = to_string(filter || "all")
    filters = ["all", "open"] ++ Enum.map(@lanes, & &1.id)

    if filter in filters, do: filter, else: "all"
  end

  defp valid_mode(mode) do
    mode = to_string(mode || "Launch")

    if mode in ["Launch", "Plan", "Deep Work", "Ship"] do
      mode
    else
      "Launch"
    end
  end

  defp clean_search(search) do
    search
    |> to_string()
    |> String.trim()
    |> String.slice(0, 48)
  end

  defp next_filter("all"), do: "open"
  defp next_filter("open"), do: "today"
  defp next_filter("today"), do: "review"
  defp next_filter("review"), do: "done"
  defp next_filter(_filter), do: "all"

  defp seed_todos do
    [
      %{
        id: "task-1001",
        title: "Draft launch checklist",
        body: "Turn the release plan into a shared owner-by-owner checklist.",
        lane: "today",
        priority: "P0",
        owner: "Mira",
        due: "09:30",
        tags: ["release", "ops"],
        progress: 68,
        points: 5,
        done: false
      },
      %{
        id: "task-1002",
        title: "Review animation budget",
        body: "Confirm motion timings stay crisp on low-power devices.",
        lane: "doing",
        priority: "P1",
        owner: "Noah",
        due: "11:00",
        tags: ["design", "perf"],
        progress: 45,
        points: 3,
        done: false
      },
      %{
        id: "task-1003",
        title: "Prepare customer notes",
        body: "Summarize the top workflow changes for the beta cohort.",
        lane: "review",
        priority: "P2",
        owner: "Ada",
        due: "13:15",
        tags: ["research"],
        progress: 82,
        points: 2,
        done: false
      },
      %{
        id: "task-1004",
        title: "Model offline empty states",
        body: "Map the fallback states for sync, conflict, and retry paths.",
        lane: "backlog",
        priority: "P1",
        owner: "Iris",
        due: "15:30",
        tags: ["product", "edge"],
        progress: 10,
        points: 8,
        done: false
      },
      %{
        id: "task-1005",
        title: "Ship telemetry labels",
        body: "Name the key events used by the benchmark timeline.",
        lane: "done",
        priority: "P3",
        owner: "Kai",
        due: "16:00",
        tags: ["metrics"],
        progress: 100,
        points: 2,
        done: true
      }
    ]
  end

  defp seed_activity do
    [
      %{id: "activity-1", label: "Loaded page-scoped Todo manifest", at: "09:02", tone: "sky"},
      %{id: "activity-2", label: "SSR digest rendered in shell", at: "09:01", tone: "emerald"},
      %{id: "activity-3", label: "Deferred insight queued", at: "09:00", tone: "violet"}
    ]
  end

  defp new_todo(title, params) do
    %{
      id: "task-#{System.unique_integer([:positive])}",
      title: title,
      body: String.trim(params["body"] || "Created from the React island."),
      lane: Map.get(params, "lane", "today"),
      priority: Map.get(params, "priority", "P2"),
      owner: String.trim(params["owner"] || "Team"),
      due: String.trim(params["due"] || "17:00"),
      tags: parse_tags(params["tags"]),
      progress: parse_int(params["progress"], 20),
      points: parse_int(params["points"], 3),
      done: false
    }
  end

  defp update_todo(todos, id, fun) do
    Enum.map_reduce(todos, "Task", fn todo, title ->
      if todo.id == id do
        updated = fun.(todo)
        {updated, updated.title}
      else
        {todo, title}
      end
    end)
  end

  defp pop_todo(todos, id) do
    todo = Enum.find(todos, &(&1.id == id)) || List.first(todos)
    {todo, Enum.reject(todos, &(&1.id == id))}
  end

  defp visible_todos(todos, filter, search) do
    search = search |> to_string() |> String.downcase()

    todos
    |> Enum.filter(fn todo ->
      filter in ["all", todo.lane] or (filter == "open" and not todo.done)
    end)
    |> Enum.filter(fn todo ->
      search == "" or
        String.contains?(String.downcase(todo.title), search) or
        Enum.any?(todo.tags, &String.contains?(String.downcase(&1), search))
    end)
  end

  defp metrics(todos, focus_sessions) do
    total = length(todos)
    done = Enum.count(todos, & &1.done)
    open = total - done
    p0 = Enum.count(todos, &(&1.priority == "P0" and not &1.done))
    points = Enum.reduce(todos, 0, &(&1.points + &2))
    completed_points = todos |> Enum.filter(& &1.done) |> Enum.reduce(0, &(&1.points + &2))
    focus = if points == 0, do: 100, else: round(completed_points / points * 100)

    %{
      total: total,
      open: open,
      done: done,
      p0: p0,
      points: points,
      focus: focus,
      focus_sessions: focus_sessions
    }
  end

  defp log_activity(socket, label, tone) do
    at =
      DateTime.utc_now()
      |> Calendar.strftime("%H:%M:%S")

    stream_insert(
      socket,
      :activity,
      %{id: "activity-#{System.unique_integer([:positive])}", label: label, at: at, tone: tone},
      at: 0,
      limit: 8
    )
  end

  defp parse_tags(nil), do: ["new"]

  defp parse_tags(tags) do
    tags
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> ["new"]
      parsed -> parsed
    end
  end

  defp parse_int(value, fallback) do
    case Integer.parse(to_string(value)) do
      {number, _rest} -> number
      :error -> fallback
    end
  end

  defp open_lane("done"), do: "today"
  defp open_lane(lane), do: lane

  defp progress_for_lane("backlog", progress), do: min(progress, 20)
  defp progress_for_lane("today", progress), do: max(progress, 30)
  defp progress_for_lane("doing", progress), do: max(progress, 55)
  defp progress_for_lane("review", progress), do: max(progress, 80)
  defp progress_for_lane("done", _progress), do: 100
  defp progress_for_lane(_lane, progress), do: progress

  defp priority_rank("P0"), do: 0
  defp priority_rank("P1"), do: 1
  defp priority_rank("P2"), do: 2
  defp priority_rank(_priority), do: 3
end
