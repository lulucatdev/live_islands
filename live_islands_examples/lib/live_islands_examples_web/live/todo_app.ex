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
      |> assign(:focus_goal, 45)
      |> assign(:focus_sessions, 2)
      |> stream(:activity, seed_activity())

    {:ok, socket}
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
    socket =
      socket
      |> assign(:filter, Map.get(params, "filter", socket.assigns.filter))
      |> assign(:search, Map.get(params, "search", socket.assigns.search))

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
    socket =
      socket
      |> assign(:mode, mode)
      |> log_activity("Vue rhythm switched to #{mode}", "emerald")

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
      |> assign(:mode, "Plan")
      |> log_activity("Promoted backlog into today's plan", "violet")

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
      |> assign(:mode, "Ship")
      |> log_activity("Shipped review lane", "emerald")

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
