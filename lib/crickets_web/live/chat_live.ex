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
      |> assign(:currently_chatting_with, nil)
      |> assign(:friends, Presence.list(@online_users_presence_topic)) # TODO narrow to friends
    }  end

  def render(assigns) do
    ~H"""
    <%!-- Main container --%>
    <div class="chat-container">
      <%!-- Friends --%>
      <div class="friends-container">
        <%= for friend <- Map.keys(@friends) do %>
          <div
            phx-click="friend-clicked"
            phx-value-friend-name={"#{friend}"}
            class={"#{if(friend == @currently_chatting_with, do: "selected-friend", else: "friend")}"}
          >
            <%=friend%>
          </div>
        <% end %>
      </div>
      <%!-- Message Header --%>
      <div class="msg-container">
        <%!-- Who you're talking to --%>
        <div
          class={"#{if(@currently_chatting_with, do: "msg-header", else: "msg-header-inactive")}"}
        >
          <%= if @currently_chatting_with do %>
            Chatting with <%=if(@currently_chatting_with == @me, do: "myself", else: @currently_chatting_with)%>
            <% else %>
            Select a friend to chat with.
          <% end %>
        </div>
        <%!-- Conversations --%>
        <div
          class={"#{if(@currently_chatting_with, do: "msg-page", else: "msg-page-inactive")}"}
        >
          <%= if @chats && @chats[@currently_chatting_with] do %>
            <%= for chat <- @chats[@currently_chatting_with] do %>
              <p
                class={"#{if(chat.from == @me, do: "my-message", else: "friends-message")}"}
              >
                <%=if(chat.from == @me, do: "me", else: chat.from)%>:
                <%=chat.message%>
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

  def handle_event("friend-clicked", %{"friend-name" => friend}, socket) do
    {
      :noreply,
      socket
      |> assign(:currently_chatting_with, friend)
    }
  end

  def handle_event("new-message-submitted", %{"messageInput" => message}, socket) do
    chat_message = %ChatMessage{
      :from => socket.assigns.me,
      :to => socket.assigns.currently_chatting_with,
      :message => message,
      :at => DateTime.utc_now()
    }

    if chat_message.from != chat_message.to do
      CricketsWeb.Endpoint.broadcast!(
        chat_message.to,
        "new_msg",
        Jason.encode!(chat_message)
      )
    end

    {
      :noreply,
      socket
      |> handle_new_chat_message(chat_message)
    }
  end

  # TODO add handle_event to update socket.assigns[:to]

  def handle_info(%Phoenix.Socket.Broadcast{event: "new_msg", payload: payload}, socket) do
    chat_message = Jason.decode!(payload)
    chat_message = %ChatMessage{
      from: Map.get(chat_message, "from"),
      to: Map.get(chat_message, "to"),
      message: Map.get(chat_message, "message"),
      at: Map.get(chat_message, "at")
    }

    {
      :noreply,
      socket
      |> handle_new_chat_message(chat_message)
    }
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_new_chat_message(socket, chat_message = %ChatMessage{}) do
    IO.inspect(chat_message)

    chatting_with = if(chat_message.to == socket.assigns.me, do: chat_message.from, else: chat_message.to)

    chats = if Map.has_key?(socket.assigns.chats, chatting_with) do
      Map.put(socket.assigns.chats, chatting_with, [chat_message | Map.get(socket.assigns.chats, chatting_with)])
    else
      Map.put(socket.assigns.chats, chatting_with, [chat_message])
    end

    update(socket, :chats, fn _ -> chats end)
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
