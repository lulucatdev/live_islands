defmodule LiveIslandsExamplesWeb.LiveCapabilities do
  use LiveIslandsExamplesWeb, :live_view

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">LiveIslands Capabilities</h1>
    <div class="grid gap-6">
      <.react
        name="Capabilities"
        socket={@socket}
        entries={@streams.entries}
        profile={@profile_form}
        documentUpload={@uploads.documents}
        uploadedFiles={@uploaded_files}
        ssr={false}
        client={:visible}
        prefetch={:load}
      />
      <.react
        id="prefetch-probe"
        class="hidden"
        name="Simple"
        ssr={false}
        client={:none}
        prefetch={:load}
      />
      <.react
        id="intent-prefetch-probe"
        class="hidden"
        name="SimpleProps"
        title="Intent prefetch"
        ssr={false}
        client={:none}
        prefetch={:intent}
      />
      <.react_server id="server-only-react" class="hidden" name="Simple" />
      <.vue
        id="vue-capabilities"
        v-component="status"
        v-socket={@socket}
        v-ssr={false}
        client={:visible}
        prefetch={:idle}
        message={@vue_message}
        v-on:ping={JS.push("vue-ping")}
      />
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:profile_form, profile_form(%{"email" => "ada@example.com"}))
      |> assign(:uploaded_files, [])
      |> assign(:vue_message, "Vue island ready")
      |> allow_upload(:documents, accept: ~w(.txt), max_entries: 1)
      |> stream(:entries, [
        %{id: 1, body: "Initial stream row"}
      ])

    {:ok, socket}
  end

  def handle_event("add-stream", _params, socket) do
    id = System.unique_integer([:positive])

    socket =
      stream_insert(socket, :entries, %{
        id: id,
        body: "Stream row #{id}"
      })

    {:noreply, socket}
  end

  def handle_event("lookup", %{"query" => query}, socket) do
    {:reply, %{message: "Reply for #{query}"}, socket}
  end

  def handle_event("vue-ping", %{"source" => source}, socket) do
    {:noreply, assign(socket, :vue_message, "Vue replied from #{source}")}
  end

  def handle_event("profile-validate", %{"profile" => params}, socket) do
    errors =
      if String.contains?(params["email"] || "", "@") do
        []
      else
        [email: {"must include @", []}]
      end

    socket = assign(socket, :profile_form, profile_form(params, errors))
    {:reply, %{valid: errors == []}, socket}
  end

  def handle_event("profile-save", %{"profile" => params}, socket) do
    socket = assign(socket, :profile_form, profile_form(params))
    {:reply, %{reset: true, email: params["email"]}, socket}
  end

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  def handle_event("save-upload", _params, socket) do
    uploaded =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        {:ok, %{name: entry.client_name, size: File.stat!(path).size}}
      end)

    {:noreply, update(socket, :uploaded_files, &(uploaded ++ &1))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  defp profile_form(params, errors \\ []) do
    to_form(params, as: :profile, errors: errors, action: :validate)
  end
end
