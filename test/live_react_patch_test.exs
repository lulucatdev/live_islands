defmodule LiveReactPatchTest do
  use ExUnit.Case

  alias LiveReact.Patch

  describe "serialization" do
    test "round-trips scalar values" do
      patches = [
        %{op: "replace", path: "/count", value: 6},
        %{op: "replace", path: "/enabled", value: true},
        %{op: "replace", path: "/title", value: "Published"},
        %{op: "replace", path: "/empty", value: nil}
      ]

      assert serialize_deserialize(patches) == patches
    end

    test "round-trips nested objects and lists" do
      patches = [
        %{op: "replace", path: "/profile/name", value: "Ada"},
        %{op: "add", path: "/items/-", value: %{"id" => 1, "name" => "Keyboard"}},
        %{op: "remove", path: "/items/0"}
      ]

      assert serialize_deserialize(patches) == patches
    end

    test "round-trips UTF-8 path and value byte lengths" do
      patches = [%{op: "replace", path: "/profile/na.me", value: "zażółć"}]

      assert serialize_deserialize(patches) == patches
    end

    test "omits nonce operations" do
      patches = [
        %{op: "test", path: "", value: 123},
        %{op: "replace", path: "/count", value: 7}
      ]

      assert serialize_deserialize(patches) == [%{op: "replace", path: "/count", value: 7}]
    end

    test "round-trips stream operations" do
      patches = [
        %{op: "upsert", path: "/users/-", value: %{"id" => 1, "name" => "Ada"}},
        %{op: "limit", path: "/users", value: 10}
      ]

      assert serialize_deserialize(patches) == patches
    end
  end

  defp serialize_deserialize(patches) do
    patches
    |> Patch.serialize()
    |> Patch.deserialize()
    |> Enum.map(&patch_from_wire/1)
  end

  defp patch_from_wire([op, path]), do: %{op: op, path: path}
  defp patch_from_wire([op, path, value]), do: %{op: op, path: path, value: value}
end
