defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  def mount(params, session, socket) do
    # IO.puts("------------------------")
    # IO.inspect(params)
    # IO.inspect(session)
    # IO.inspect(socket)
    # IO.puts("------------------------")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>hi <%= @current_user.email %>!</div>
    <div class="flex">
      <div>Friends List</div>
      <div>Chat Box</div>
    </div>
    """
  end

end
