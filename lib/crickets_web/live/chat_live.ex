defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view
  alias Crickets.ChatMessage

  def mount(_params, _session, socket) do
    socket = assign(socket, :me, socket.assigns.current_user.email)

    # This will contain a map of email: ChatMessages
    socket = assign(socket, :chats, %{})

    # Only interested in messages directed at me
    CricketsWeb.Endpoint.subscribe(socket.assigns[:me])

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

          <%= if @chats && @chats[@me] do %>
          <%= for chat <- @chats[@me] do %>
            <p>
              <%=chat["from"]%>:&nbsp;<%=chat["message"]%>
            </p>
          <% end %>
          <% end %>
        </div>
        <%!-- Message input --%>
        <div class="msg-input-container">
          <form phx-submit="new-message-submitted">
            <textarea name="messageInput" />
            <%!-- One can either hit ENTER in the above text input or click the below button. --%>
            <button type="submit">Go</button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("new-message-submitted", %{"messageInput" => message}, socket) do
    chat_message = %ChatMessage{
      :from => socket.assigns[:me],
      :message => message,
      :at => DateTime.utc_now()
    }

    CricketsWeb.Endpoint.broadcast!(socket.assigns[:me], "new_msg", Jason.encode!(chat_message))

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: _topic, event: "new_msg", payload: payload}, socket) do
    chat_message = Jason.decode!(payload)

    from = chat_message["from"]

    existing_chats = socket.assigns[:chats]

    chats = if Map.has_key?(existing_chats, from) do
      Map.put(existing_chats, from, [chat_message | Map.get(existing_chats, from)])
    else
      Map.put(existing_chats, from, [chat_message])
    end

    socket = update(socket, :chats, fn _ -> chats end)

    # IO.inspect(socket)
    {:noreply, socket}
  end
end
