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
    <%!-- <div>hi <%= @current_user.email %>!</div> --%>
    <%!-- Main container --%>
    <div class="chat-container">
      <%!-- Friends --%>
      <div class="friends-container">
      </div>
      <%!-- Message Header --%>
      <div class="msg-container">
        <%!-- Who you're talking to --%>
        <div class="msg-header">
        </div>
        <%!-- Conversations --%>
        <div class="msg-page">
        </div>
        <%!-- Message input --%>
        <div class="msg-input-container">
          <textarea class="msg-input" />
          <button>Send</button>
        </div>
      </div>
    </div>
    """
  end

end
