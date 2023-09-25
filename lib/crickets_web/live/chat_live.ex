defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>hi!</div>
    """
  end

end
