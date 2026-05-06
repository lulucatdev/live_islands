defmodule LiveIslandsExamplesWeb.LiveDemoAssigns do
  @moduledoc """
  Assigns the current demo state.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket = attach_hook(socket, :active_tab, :handle_params, &set_active_demo/3)
    {:cont, socket}
  end

  defp set_active_demo(_params, _url, socket) do
    demo =
      case {socket.view, socket.assigns.live_action} do
        {LiveIslandsExamplesWeb.LiveCounter, _} ->
          :counter

        {LiveIslandsExamplesWeb.LiveLogList, _} ->
          :log_list

        {LiveIslandsExamplesWeb.LiveFlashSonner, _} ->
          :flash_sonner

        {LiveIslandsExamplesWeb.LiveSSR, _} ->
          :ssr

        {LiveIslandsExamplesWeb.LiveHybridForm, _} ->
          :hybrid_form

        {LiveIslandsExamplesWeb.LiveSlot, _} ->
          :slot

        {LiveIslandsExamplesWeb.LiveContext, _} ->
          :context

        {LiveIslandsExamplesWeb.LiveLinkDemo, _} ->
          :link_demo

        {LiveIslandsExamplesWeb.LiveLinkUsage, _} ->
          :link_usage

        {LiveIslandsExamplesWeb.LiveCapabilities, _} ->
          :capabilities

        {LiveIslandsExamplesWeb.LiveBenchmarks, _} ->
          :benchmarks

        {_view, _live_action} ->
          nil
      end

    {:cont, assign(socket, demo: demo)}
  end
end
