defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  alias Crickets.ChatMessage
  alias CricketsWeb.Presence

  # Topic to track which users are online
  @online_users_presence_topic "crickets:online_users_presence_topic"

  def mount(_params, _session, socket) do
    me = socket.assigns.current_user.email

    # Track me so that my friends can see when I'm online.
    Presence.track(
      self(),
      @online_users_presence_topic,
      me,
      %{}
    )

    # Interested in messages directed at me. Each user has a topic named after his/her email.
    CricketsWeb.Endpoint.subscribe(me)
    # Interested in getting updates about which of my friends are online.
    CricketsWeb.Endpoint.subscribe(@online_users_presence_topic)

    {
      :ok,
      socket
      |> assign(:me, me)
      |> assign(:chats, %{}) # no chat history to start with
      |> assign(:friends, Presence.list(@online_users_presence_topic)) # TODO narrow to friends
    }  end

  def render(assigns) do
    # TODO - When you click on a friend, change context to him/her.
    ~H"""
    <%!-- Main container --%>
    <div class="chat-container">
      <%!-- Friends --%>
      <div class="friends-container">
        <%= for friend <- Map.keys(@friends) do %>
          <p>
            <%=friend%>
          </p>
        <% end %>
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

    # TODO write to socket.assigns[:chats][socket.assigns[:to]]
    # TODO broadcast to socket.assigns[:to] instead
    CricketsWeb.Endpoint.broadcast!(socket.assigns[:me], "new_msg", Jason.encode!(chat_message))

    {:noreply, socket}
  end

  # TODO add handle_event to update socket.assigns[:to]

  def handle_info(%Phoenix.Socket.Broadcast{event: "new_msg", payload: payload}, socket) do
    chat_message = Jason.decode!(payload)

    from = chat_message["from"]

    chats = if Map.has_key?(socket.assigns.chats, from) do
      Map.put(socket.assigns.chats, from, [chat_message | Map.get(socket.assigns.chats, from)])
    else
      Map.put(socket.assigns.chats, from, [chat_message])
    end

    socket = update(socket, :chats, fn _ -> chats end)

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    Enum.reduce(joins, socket, fn {user, %{metas: [meta| _]}}, socket ->
      assign(socket, :friends, Map.put(socket.assigns.friends, user, meta))
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {user, _}, socket ->
      assign(socket, :friends, Map.delete(socket.assigns.friends, user))
    end)
  end

end
