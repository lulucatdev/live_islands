defmodule LiveVue do
  @moduledoc """
  Compatibility module for Vue users inside LiveIslands.

  New code should prefer `LiveIslands.vue/1`.
  """

  defmacro __using__(_opts) do
    quote do
      import LiveVue
    end
  end

  def vue(assigns), do: LiveIslands.vue(assigns)
end
