defmodule LiveIslandsTest do
  use ExUnit.Case

  import LiveIslands
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias LiveIslands.Test
  alias Phoenix.LiveView.JS

  doctest LiveIslands

  describe "React and Vue islands" do
    def mixed_component(assigns) do
      ~H"""
      <div>
        <.react id="react-card" name="ReactCard" title="React" client={:visible} />
        <.vue
          id="vue-card"
          v-component="VueCard"
          count={2}
          client={{:media, "(min-width: 800px)"}}
          v-on:click={JS.push("save")}
        >
          Vue body
          <:header>Vue header</:header>
        </.vue>
      </div>
      """
    end

    test "renders React islands through the shared LiveIslands entrypoint" do
      html = render_component(&mixed_component/1)
      island = Test.get_react(html)

      assert island.framework == "react"
      assert island.component == "ReactCard"
      assert island.props == %{"title" => "React"}
      assert island.id == "react-card"
      assert island.client == "visible"
    end

    test "renders Vue islands with named slots and handlers" do
      html = render_component(&mixed_component/1)
      island = Test.get_vue(html)

      assert island.framework == "vue"
      assert island.component == "VueCard"
      assert island.props == %{"count" => 2}
      assert island.slots == %{"default" => "Vue body", "header" => "Vue header"}
      assert island.handlers == %{"click" => [["push", %{"event" => "save"}]]}
      assert island.client == "media"
      assert island.client_media == "(min-width: 800px)"
    end
  end
end
