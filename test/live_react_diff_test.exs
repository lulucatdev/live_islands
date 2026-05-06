defmodule LiveReactDiffTest do
  use ExUnit.Case

  import Phoenix.Component

  alias LiveReact.Test
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.LiveStream

  defmodule Team do
    @moduledoc false
    @derive LiveReact.Encoder
    defstruct [:id, :name, :members]
  end

  defmodule StreamUser do
    @moduledoc false
    @derive LiveReact.Encoder
    defstruct [:id, :name, :age]
  end

  defp render_react_assigns(assigns) do
    assigns
    |> LiveReact.react()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> Test.get_react()
  end

  defp decode_patch(patch_list) do
    patch_list
    |> Enum.map(fn
      [op, path] -> %{"op" => op, "path" => path}
      [op, path, value] -> %{"op" => op, "path" => path, "value" => value}
    end)
  end

  defp assert_patches_equal(actual, expected) do
    actual_sorted = actual |> decode_patch() |> Enum.sort_by(& &1["path"])
    expected_sorted = Enum.sort_by(expected, & &1["path"])

    assert actual_sorted == expected_sorted
  end

  describe "props diffing" do
    test "initial render sends full props and no diff" do
      react =
        render_react_assigns(%{
          title: "Initial",
          count: 1,
          name: "Card",
          __changed__: nil
        })

      assert react.component == "Card"
      assert react.props == %{"title" => "Initial", "count" => 1}
      assert react.use_diff == true
      assert_patches_equal(react.props_diff, [])
    end

    test "simple prop changes create replace operations" do
      assigns = %{
        title: "Initial",
        count: 1,
        name: "Card",
        __changed__: %{}
      }

      react = assigns |> assign(:title, "Updated") |> render_react_assigns()

      assert_patches_equal(react.props_diff, [
        %{"op" => "replace", "path" => "/title", "value" => "Updated"}
      ])
    end

    test "complex prop changes use JSON Patch operations over encoded structs" do
      assigns = %{
        team: %Team{id: 1, name: "Core", members: ["Ada"]},
        name: "Card",
        __changed__: %{}
      }

      react =
        assigns
        |> assign(:team, %Team{id: 1, name: "Core", members: ["Ada", "Grace"]})
        |> render_react_assigns()

      assert_patches_equal(react.props_diff, [
        %{"op" => "add", "path" => "/team/members/1", "value" => "Grace"}
      ])
    end

    test "event handler attributes become handler metadata" do
      react =
        render_react_assigns(%{
          name: "Button",
          "on:click": JS.push("save"),
          __changed__: nil
        })

      assert react.handlers == %{"click" => [["push", %{"event" => "save"}]]}
    end
  end

  describe "LiveStream diffing" do
    test "initial render sends streams through stream diffs" do
      users = [
        %StreamUser{id: 1, name: "Ada", age: 36},
        %StreamUser{id: 2, name: "Grace", age: 85}
      ]

      stream = LiveStream.new(:users, make_ref(), users, [])

      react =
        render_react_assigns(%{
          users: stream,
          name: "List",
          __changed__: nil
        })

      assert react.props == %{}

      assert_patches_equal(react.streams_diff, [
        %{"op" => "replace", "path" => "/users", "value" => []},
        %{
          "op" => "upsert",
          "path" => "/users/-",
          "value" => %{"__dom_id" => "users-1", "age" => 36, "id" => 1, "name" => "Ada"}
        },
        %{
          "op" => "upsert",
          "path" => "/users/-",
          "value" => %{"__dom_id" => "users-2", "age" => 85, "id" => 2, "name" => "Grace"}
        }
      ])
    end

    test "inserted stream items become upserts" do
      stream =
        :users
        |> LiveStream.new(make_ref(), [], [])
        |> LiveStream.insert_item(%StreamUser{id: 3, name: "Katherine", age: 101}, -1, nil)

      react =
        render_react_assigns(%{
          users: stream,
          name: "List",
          __changed__: %{users: LiveStream.new(:users, make_ref(), [], [])}
        })

      assert_patches_equal(react.streams_diff, [
        %{"op" => "replace", "path" => "/users", "value" => []},
        %{
          "op" => "upsert",
          "path" => "/users/-",
          "value" => %{"__dom_id" => "users-3", "age" => 101, "id" => 3, "name" => "Katherine"}
        }
      ])
    end
  end
end
