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
        <.react
          id="react-card"
          name="ReactCard"
          title="React"
          client={:interaction}
          prefetch={:idle}
        />
        <.vue
          id="vue-card"
          v-component="VueCard"
          count={2}
          client={{:media, "(min-width: 800px)"}}
          prefetch={{:media, "(min-width: 1024px)"}}
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
      assert island.client == "interaction"
      assert island.prefetch == "idle"
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
      assert island.prefetch == "media"
      assert island.prefetch_media == "(min-width: 1024px)"
    end

    def intent_component(assigns) do
      ~H"""
      <.react id="intent-card" name="IntentCard" prefetch={:intent} />
      """
    end

    test "renders intent-aware prefetch policy" do
      html = render_component(&intent_component/1)
      island = Test.get_react(html, id: "intent-card")

      assert island.prefetch == "intent"
    end

    def server_component(assigns) do
      ~H"""
      <div>
        <.react_server id="server-react" name="ServerReact" title="Static React" />
        <.vue_server id="server-vue" v-component="ServerVue" title="Static Vue" />
      </div>
      """
    end

    test "renders first-class server-only islands without LiveView hooks" do
      html = render_component(&server_component/1)

      react = Test.get_react(html, id: "server-react")
      vue = Test.get_vue(html, id: "server-vue")

      assert react.server_only
      assert react.client == "none"
      assert react.prefetch == "none"
      assert react.hook == nil
      assert react.phx_update == nil

      assert vue.server_only
      assert vue.client == "none"
      assert vue.prefetch == "none"
      assert vue.hook == nil
      assert vue.phx_update == nil
    end
  end
end
