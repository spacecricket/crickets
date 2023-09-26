defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  def mount(_params, _session, socket) do
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
      <div>
      <ol>
        <li>Coffee</li>
        <li>Tea</li>
        <li>Milk</li>
      </ol>
      </div>
      <div>

      </div>
    </div>
    """
  end

end
