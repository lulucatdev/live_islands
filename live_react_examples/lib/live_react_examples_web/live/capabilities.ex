defmodule LiveReactExamplesWeb.LiveCapabilities do
  use LiveReactExamplesWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1 class="flex justify-center mb-10 font-bold">LiveReact Capabilities</h1>
    <.react
      name="Capabilities"
      socket={@socket}
      entries={@streams.entries}
      profile={@profile_form}
      documentUpload={@uploads.documents}
      uploadedFiles={@uploaded_files}
      ssr={false}
    />
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:profile_form, profile_form(%{"email" => "ada@example.com"}))
      |> assign(:uploaded_files, [])
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
