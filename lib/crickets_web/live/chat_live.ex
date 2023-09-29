defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  alias CricketsWeb.Presence
  alias Crickets.ChatMessage

  # Topic to track which users are online
  @online_users_presence_topic "crickets:online_users_presence_topic"

  def mount(_params, _session, socket) do
    me = socket.assigns.current_user.handle || socket.assigns.current_user.email

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
      |> assign(:currently_chatting_with, me)
      |> assign(:outbound_message_count, 0) # a hack to clear out the just-submitted message from the textarea
      |> assign(:voicemail, %{}) # not a good name. messages_pending?
      |> assign(:friends, Presence.list(@online_users_presence_topic)) # TODO narrow to friends
    }
  end

  def render(assigns) do
    ~H"""
    <%!-- Main container --%>
    <div class="chat-container">
      <%!-- Friends --%>
      <div class="friends-container">
        <%= for friend <- Map.keys(@friends) do %>
          <%= cond do %>
            <% friend == @currently_chatting_with -> %>
              <div
                phx-click="friend-clicked"
                phx-value-friend-name={"#{friend}"}
                class="selected-friend"
              >
                <%=if friend == @me, do: "Me", else: friend <> " 💬" %>
              </div>
            <% Map.has_key?(@voicemail, friend) -> %>
              <div
                phx-click="friend-clicked"
                phx-value-friend-name={"#{friend}"}
                class="unread-friend"
              >
                <%=if friend == @me, do: "Me", else: friend%> 💬
              </div>
            <% true -> %>
              <div
                phx-click="friend-clicked"
                phx-value-friend-name={"#{friend}"}
                class="friend"
              >
                <%=if friend == @me, do: "Me", else: friend%>
              </div>
          <% end %>
        <% end %>
      </div>
      <div class="msg-container">
        <%!-- Message input --%>
        <div class="msg-input-container">
            <textarea
              id={"#{@outbound_message_count}"}
              name="messageInput"
              placeholder=".."
              class="msg-input"
              phx-keydown="send-message"
              phx-key="Enter"
              phx-hook="Focus"
            />
        </div>
        <%!-- Conversations --%>
        <div
          class="msg-page"
        >
          <%= if @chats && @chats[@currently_chatting_with] do %>
            <%= for {chat, i} <- Enum.with_index(@chats[@currently_chatting_with]) do %>
              <%= if i < 10 do %>
                <p
                  class={"#{if(chat.from == @me, do: "my-message", else: "friends-message")} #{if(i == 0, do: "latest-message")}"}
                  style={"opacity: #{1.0 - i * 0.1}"}
                >
                  <%= for part <- String.split(chat.message, "\n") do %>
                    <%= part %>
                    <br />
                  <% end %>
                </p>
              <% end %>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Called when user tries to send a message.
  def handle_event("send-message", %{"shiftKey" => isShiftKeyPressed, "value" => message}, socket) do
    # Shift + Enter allows the user to put a newline in the message.
    if !isShiftKeyPressed do
      chat_message = %ChatMessage{
        :from => socket.assigns.me,
        :to => socket.assigns.currently_chatting_with,
        :message => message,
        :at => DateTime.utc_now()
      }

      CricketsWeb.Endpoint.broadcast!(
        chat_message.to,
        "new_msg",
        Jason.encode!(chat_message)
      )

      if chat_message.from != chat_message.to do
        {
          :noreply,
          socket
          |> assign(:outbound_message_count, 1 + socket.assigns.outbound_message_count)
          |> handle_new_chat_message(chat_message) # don't want duplicate messages when chatting with yourself
        }
      else
        {
          :noreply,
          socket
          |> assign(:outbound_message_count, 1 + socket.assigns.outbound_message_count)
        }
      end

    else
      {:noreply, socket}
    end
  end

  def handle_event("friend-clicked", %{"friend-name" => friend}, socket) do
    {
      :noreply,
      socket
      |> assign(:currently_chatting_with, friend)
      |> update(:voicemail, fn _ -> Map.delete(socket.assigns.voicemail, friend) end)
    }
  end

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
    chatting_with = if(chat_message.to == socket.assigns.me, do: chat_message.from, else: chat_message.to)

    chats = if Map.has_key?(socket.assigns.chats, chatting_with) do
      Map.put(socket.assigns.chats, chatting_with, [chat_message | Map.get(socket.assigns.chats, chatting_with)])
    else
      Map.put(socket.assigns.chats, chatting_with, [chat_message])
    end

    voicemail = if chatting_with != socket.assigns.currently_chatting_with do
      Map.put(socket.assigns.voicemail, chatting_with, true)
    else
      socket.assigns.voicemail
    end

    socket = update(socket, :chats, fn _ -> chats end)
    update(socket, :voicemail, fn _ -> voicemail end)
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
