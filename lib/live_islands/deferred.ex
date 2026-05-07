defmodule LiveIslands.Deferred do
  @moduledoc """
  Signed deferred server-island rendering endpoint.

  Mount this plug in the host Phoenix router:

      forward "/live-islands/deferred", LiveIslands.Deferred,
        endpoint: MyAppWeb.Endpoint

  Deferred server islands render a fallback in the initial page HTML and fetch
  their final SSR HTML from this endpoint after the page has started loading.
  """

  @behaviour Plug

  import Plug.Conn

  alias LiveIslands.SSR

  @default_path "/live-islands/deferred"
  @salt "live_islands:deferred:v1"
  @default_max_age 3_600

  @typedoc "A signed deferred island payload."
  @type payload :: %{
          required(:framework) => :react | :vue | String.t(),
          required(:name) => String.t(),
          required(:props) => map,
          required(:slots) => map,
          optional(:cache_control) => String.t()
        }

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    conn = fetch_query_params(conn)

    endpoint =
      Keyword.get(opts, :endpoint) || Application.get_env(:live_islands, :deferred_endpoint)

    max_age = Keyword.get(opts, :max_age, deferred_max_age())
    token = conn.params["token"]

    with {:method, true} <- {:method, conn.method in ["GET", "HEAD"]},
         {:endpoint, endpoint} when not is_nil(endpoint) <- {:endpoint, endpoint},
         {:token, token} when is_binary(token) <- {:token, token},
         {:ok, payload} <- verify(endpoint, token, max_age: max_age),
         {:ok, html, cache_control} <- render(payload) do
      conn
      |> put_resp_header("cache-control", cache_control)
      |> put_resp_content_type("text/html")
      |> send_resp(200, html)
    else
      {:method, false} ->
        conn
        |> put_resp_header("allow", "GET, HEAD")
        |> send_resp(405, "method not allowed")

      {:endpoint, nil} ->
        send_resp(conn, 500, "deferred endpoint is not configured")

      {:token, _} ->
        send_resp(conn, 400, "missing deferred token")

      {:error, _reason} ->
        send_resp(conn, 403, "invalid deferred token")

      {:render_error, message} ->
        send_resp(conn, 500, message)
    end
  end

  @doc """
  Returns the configured deferred endpoint path.
  """
  @spec path :: String.t()
  def path do
    Application.get_env(:live_islands, :deferred_path, @default_path)
  end

  @doc """
  Signs a deferred island payload with the configured or supplied Phoenix endpoint.
  """
  @spec sign(payload, keyword) :: String.t()
  def sign(payload, opts \\ []) when is_map(payload) do
    endpoint =
      Keyword.get(opts, :endpoint) || Application.fetch_env!(:live_islands, :deferred_endpoint)

    Phoenix.Token.sign(endpoint, salt(opts), payload)
  end

  @doc """
  Builds a signed URL path for a deferred island payload.
  """
  @spec signed_path(payload, keyword) :: String.t()
  def signed_path(payload, opts \\ []) when is_map(payload) do
    path = Keyword.get(opts, :path) || path()
    token = Keyword.get(opts, :token) || sign(payload, opts)
    separator = if String.contains?(path, "?"), do: "&", else: "?"

    path <> separator <> URI.encode_query(token: token)
  end

  @doc """
  Verifies a signed deferred island token.
  """
  @spec verify(module, String.t(), keyword) :: {:ok, payload} | {:error, term}
  def verify(endpoint, token, opts \\ []) do
    Phoenix.Token.verify(endpoint, salt(opts), token,
      max_age: Keyword.get(opts, :max_age, deferred_max_age())
    )
  end

  @doc false
  @spec render(payload) :: {:ok, String.t(), String.t()} | {:render_error, String.t()}
  def render(payload) when is_map(payload) do
    framework = payload_value(payload, :framework)
    name = payload_value(payload, :name)
    props = payload_value(payload, :props) || %{}
    slots = payload_value(payload, :slots) || %{}
    cache_control = payload_value(payload, :cache_control) || "no-store"

    meta = %{framework: framework, component: name}

    :telemetry.span([:live_islands, :deferred], meta, fn ->
      result = SSR.render(normalize_framework(framework), name, props, slots)
      html = result[:html] || result["html"] || ""
      {{:ok, html, cache_control}, meta}
    end)
  rescue
    exception ->
      {:render_error, Exception.message(exception)}
  end

  defp payload_value(payload, key) do
    Map.get(payload, key) || Map.get(payload, Atom.to_string(key))
  end

  defp normalize_framework(:react), do: :react
  defp normalize_framework(:vue), do: :vue
  defp normalize_framework("react"), do: :react
  defp normalize_framework("vue"), do: :vue
  defp normalize_framework(value), do: value

  defp salt(opts), do: Keyword.get(opts, :salt, @salt)

  defp deferred_max_age do
    Application.get_env(:live_islands, :deferred_token_max_age, @default_max_age)
  end
end
