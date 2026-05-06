defprotocol LiveIslands.Encoder do
  @moduledoc """
  Encodes values before they are sent to React components.

  The protocol is similar to `Jason.Encoder`, but it returns plain Elixir data
  rather than an encoded JSON string. This makes struct exposure explicit and
  allows LiveIslands to calculate JSON patches over encoded values.
  """

  @type t :: term
  @type opts :: Keyword.t()

  @fallback_to_any true

  @doc """
  Encodes a value to JSON-compatible data.
  """
  @spec encode(t, opts) :: any()
  def encode(value, opts \\ [])
end

defimpl LiveIslands.Encoder, for: Integer do
  def encode(value, _opts), do: value
end

defimpl LiveIslands.Encoder, for: Float do
  def encode(value, _opts), do: value
end

defimpl LiveIslands.Encoder, for: BitString do
  def encode(value, _opts), do: value
end

defimpl LiveIslands.Encoder, for: Atom do
  def encode(value, _opts), do: value
end

defimpl LiveIslands.Encoder, for: List do
  def encode(list, opts), do: Enum.map(list, &LiveIslands.Encoder.encode(&1, opts))
end

defimpl LiveIslands.Encoder, for: Map do
  def encode(map, opts) do
    Map.new(map, fn {key, value} -> {key, LiveIslands.Encoder.encode(value, opts)} end)
  end
end

defimpl LiveIslands.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  def encode(value, _opts), do: @for.to_iso8601(value)
end

defimpl LiveIslands.Encoder, for: Phoenix.HTML.Form do
  def encode(%Phoenix.HTML.Form{} = form, opts) do
    LiveIslands.Encoder.encode(
      %{
        name: form.name,
        values: encode_form_values(form, opts),
        errors: encode_form_errors(form) || %{},
        valid: get_form_validity(form)
      },
      opts
    )
  rescue
    error in [Protocol.UndefinedError] ->
      reraise maybe_enhance_error(error), __STACKTRACE__
  end

  defp get_form_validity(%{source: %{valid?: valid}}), do: valid
  defp get_form_validity(_), do: true

  if Code.ensure_loaded?(Ecto) do
    defp maybe_enhance_error(%{value: %Ecto.Association.NotLoaded{}} = error) do
      Map.update!(error, :description, fn description ->
        [first | rest] = String.split(description, "\n\n")

        addition = """
        To prevent this error in forms, encode the form with the `nilify_not_loaded: true` option.
        """

        Enum.join([first | [addition | rest]], "\n\n")
      end)
    end

    defp maybe_enhance_error(error), do: error
  else
    defp maybe_enhance_error(error), do: error
  end

  if Code.ensure_loaded?(Ecto) do
    @relations [:embed, :assoc]

    defp collect_changeset_values(%Ecto.Changeset{} = source, opts) do
      data =
        Map.new(source.types, fn {field, type} ->
          {field, get_field_value(source, field, type, opts)}
        end)

      result = if is_struct(source.data), do: Map.merge(source.data, data), else: data

      Map.delete(result, :__meta__)
    end

    defp get_field_value(source, field, {tag, %{cardinality: :one}}, opts)
         when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, nil} ->
          nil

        {:ok, %Ecto.Changeset{} = changeset} ->
          collect_changeset_values(changeset, opts)

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            %{__meta__: _} = value ->
              Map.delete(value, :__meta__)

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, {tag, %{cardinality: :many}}, opts)
         when tag in @relations do
      case Map.fetch(source.changes, field) do
        {:ok, changesets} ->
          changesets
          |> Enum.filter(&(&1.params != nil))
          |> Enum.map(&collect_changeset_values(&1, opts))

        :error ->
          case Map.fetch!(source.data, field) do
            %Ecto.Association.NotLoaded{} = not_loaded ->
              if opts[:nilify_not_loaded], do: nil, else: not_loaded

            [%{__meta__: _} | _] = value ->
              Enum.map(value, &Map.delete(&1, :__meta__))

            value ->
              value
          end
      end
    end

    defp get_field_value(source, field, _type, _opts) do
      Phoenix.HTML.FormData.Ecto.Changeset.input_value(source, %{params: source.params}, field)
    end

    defp collect_changeset_errors(%Ecto.Changeset{} = changeset) do
      errors = translate_errors(changeset.errors)

      Enum.reduce(changeset.changes, errors, fn {field, value}, acc ->
        case Map.get(changeset.types, field) do
          {tag, %{cardinality: :one}} when tag in @relations ->
            embed_errors = collect_changeset_errors(value)
            if embed_errors == %{}, do: acc, else: Map.put(acc, field, embed_errors)

          {tag, %{cardinality: :many}} when tag in @relations ->
            list_errors =
              value
              |> Enum.filter(&(&1.params != nil))
              |> Enum.map(fn embed_changeset ->
                embed_errors = collect_changeset_errors(embed_changeset)
                if embed_errors == %{}, do: nil, else: embed_errors
              end)

            if Enum.all?(list_errors, &is_nil/1), do: acc, else: Map.put(acc, field, list_errors)

          _ ->
            acc
        end
      end)
    end

    def encode_form_values(%{impl: Phoenix.HTML.FormData.Ecto.Changeset, source: source}, opts) do
      source |> collect_changeset_values(opts) |> LiveIslands.Encoder.encode(opts)
    end

    def encode_form_values(form, opts) do
      encode_form_values_without_ecto(form, opts)
    end

    def encode_form_errors(%{impl: Phoenix.HTML.FormData.Ecto.Changeset} = form) do
      collect_changeset_errors(form.source)
    end

    def encode_form_errors(form), do: translate_errors(form.errors)
  else
    def encode_form_values(form, opts) do
      encode_form_values_without_ecto(form, opts)
    end

    def encode_form_errors(form), do: translate_errors(form.errors)
  end

  defp encode_form_values_without_ecto(form, opts) do
    base_values =
      form.hidden
      |> Map.new()
      |> Map.merge(form.data)
      |> Map.merge(Map.new(form.params))

    LiveIslands.Encoder.encode(base_values, opts)
  end

  defp translate_errors(errors) do
    Map.new(errors, fn {field, error} ->
      {field, error |> List.wrap() |> Enum.map(&translate_error/1)}
    end)
  end

  defp translate_error({msg, opts}) do
    backend = Application.get_env(:live_islands, :gettext_backend, nil)
    count = opts[:count]

    cond do
      backend != nil and count != nil and Code.ensure_loaded?(Gettext) ->
        apply(Gettext, :dngettext, [backend, "errors", msg, msg, count, opts])

      backend != nil and Code.ensure_loaded?(Gettext) ->
        apply(Gettext, :dgettext, [backend, "errors", msg, opts])

      true ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          replacement =
            value
            |> List.wrap()
            |> Enum.map_join(", ", fn
              v when is_binary(v) or is_atom(v) or is_number(v) -> to_string(v)
              v -> inspect(v)
            end)

          String.replace(acc, "%{#{key}}", replacement)
        end)
    end
  end
end

defimpl LiveIslands.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)

    quote do
      defimpl LiveIslands.Encoder, for: unquote(module) do
        def encode(struct, opts) do
          struct
          |> Map.take(unquote(fields))
          |> LiveIslands.Encoder.encode(opts)
        end
      end
    end
  end

  def encode(%{__struct__: module} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      LiveIslands.Encoder protocol must be explicitly implemented for #{inspect(module)}.

      If the struct is owned by the application, derive the implementation with
      an explicit field list:

          @derive {LiveIslands.Encoder, only: [...]}

      If the struct comes from another dependency, use `Protocol.derive/3` or
      define a custom `defimpl LiveIslands.Encoder`.
      """
  end

  def encode(value, _opts), do: value

  defp fields_to_encode(struct, opts) do
    fields = Map.keys(struct)

    cond do
      only = Keyword.get(opts, :only) ->
        case only -- fields do
          [] ->
            only

          error_keys ->
            raise ArgumentError,
                  ":only specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      except = Keyword.get(opts, :except) ->
        case except -- fields do
          [] ->
            fields -- [:__struct__ | except]

          error_keys ->
            raise ArgumentError,
                  ":except specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      true ->
        fields -- [:__struct__]
    end
  end
end

if Code.ensure_loaded?(Phoenix.LiveView.AsyncResult) do
  defimpl LiveIslands.Encoder, for: Phoenix.LiveView.AsyncResult do
    def encode(%Phoenix.LiveView.AsyncResult{} = struct, opts) do
      LiveIslands.Encoder.encode(
        %{
          ok: struct.ok?,
          loading: struct.loading,
          failed: encode_failed(struct.failed),
          result: struct.result
        },
        opts
      )
    end

    defp encode_failed({:error, reason}), do: reason
    defp encode_failed({:exit, reason}), do: reason
    defp encode_failed(other), do: other
  end
end

if Code.ensure_loaded?(Phoenix.LiveView.UploadConfig) do
  defimpl LiveIslands.Encoder, for: Phoenix.LiveView.UploadConfig do
    def encode(%Phoenix.LiveView.UploadConfig{} = struct, opts) do
      errors =
        Enum.map(struct.errors, fn {key, value} ->
          %{ref: key, error: LiveIslands.Encoder.encode(value, opts)}
        end)

      entries =
        Enum.map(struct.entries, fn entry ->
          encoded = LiveIslands.Encoder.encode(entry, opts)
          entry_errors = errors |> Enum.filter(&(&1.ref == entry.ref)) |> Enum.map(& &1.error)
          Map.put(encoded, :errors, entry_errors)
        end)

      LiveIslands.Encoder.encode(
        %{
          ref: struct.ref,
          name: struct.name,
          accept: struct.accept,
          max_entries: struct.max_entries,
          auto_upload: struct.auto_upload?,
          entries: entries,
          errors: errors
        },
        opts
      )
    end
  end
end

if Code.ensure_loaded?(Phoenix.LiveView.UploadEntry) do
  defimpl LiveIslands.Encoder, for: Phoenix.LiveView.UploadEntry do
    def encode(%Phoenix.LiveView.UploadEntry{} = struct, opts) do
      LiveIslands.Encoder.encode(
        %{
          ref: struct.ref,
          client_name: struct.client_name,
          client_size: struct.client_size,
          client_type: struct.client_type,
          progress: struct.progress,
          done: struct.done?,
          valid: struct.valid?,
          preflighted: struct.preflighted?
        },
        opts
      )
    end
  end
end
