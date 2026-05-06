defmodule LiveIslands.Slots do
  @moduledoc false

  import Phoenix.Component

  @doc false
  def rendered_slot_map(assigns, framework \\ :react)

  def rendered_slot_map(assigns, _framework) when assigns == %{}, do: %{}

  def rendered_slot_map(assigns, framework) do
    for(
      {key, [%{__slot__: _}] = slot} <- assigns,
      into: %{},
      do:
        key
        |> normalize_slot_name(framework)
        |> then(&{&1, render(%{slot: slot})})
    )
  end

  defp normalize_slot_name(:inner_block, _framework), do: :default

  defp normalize_slot_name(:default, :vue) do
    raise "Instead of using <:default> use the default inner block slot."
  end

  defp normalize_slot_name(slot_name, :vue), do: slot_name

  defp normalize_slot_name(slot_name, :react) do
    raise "Unsupported slot: #{slot_name}, only one default slot is supported, passed as React children."
  end

  @doc false
  def base_encode_64(assigns) do
    for {key, value} <- assigns, into: %{}, do: {key, Base.encode64(value)}
  end

  @doc false
  defp render(assigns) do
    ~H"""
    <%= if assigns[:slot] do %>
      <%= render_slot(@slot) %>
    <% end %>
    """
    |> Phoenix.HTML.Safe.to_iodata()
    |> List.to_string()
    |> String.trim()
  end
end
