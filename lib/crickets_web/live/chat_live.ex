defmodule CricketsWeb.ChatLive do
  use CricketsWeb, :live_view

  alias CricketsWeb.Presence
  alias Crickets.ChatMessage

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
                <%=if friend == @me, do: "Me", else: friend%> 💬
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
        <%!-- Message Header --%>
        <%!-- Who you're talking to --%>
        <div
          class="msg-header"
        >
          Chatting with <%=if(@currently_chatting_with == @me, do: "myself", else: @currently_chatting_with)%> ☺
        </div>
        <%!-- Message input --%>
        <div class="msg-input-container">
            <textarea
              id={"#{@outbound_message_count}"}
              name="messageInput"
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
              <%= if i < 20 do %>
                <p
                  class={"#{if(chat.from == @me, do: "my-message", else: "friends-message")} #{if(i == 0, do: "latest-message")}"}
                  style={"opacity: #{1.0 - i * 0.05}"}
                >
                  <%!-- <%=if(chat.from != @me, do: chat.from <> ": ")%> --%>

                  <%= for part <- String.split(chat.message, "\n") do %>
                    <%= part %>
                    <br />
                  <% end %>
                </p>
              <% end %>
            <% end %>
          <% end %>
        </div>
        <div class="shredder">
          <svg height="40px" version="1.1" viewBox="0 0 32 32" width="40px" xmlns="http://www.w3.org/2000/svg" xmlns:sketch="http://www.bohemiancoding.com/sketch/ns" xmlns:xlink="http://www.w3.org/1999/xlink"><title/><desc/><defs/><g fill="none" fill-rule="evenodd" id="Page-1" stroke="none" stroke-width="1"><g fill="#929292" id="icon-127-shredder"><path d="M6,11 L6,4.9973917 C6,3.89585781 6.89427625,3 7.99742191,3 L23.0025781,3 C24.1090746,3 25,3.89426273 25,4.9973917 L25,11 L6,11 L6,11 Z M5,23 L3.99428189,23 C2.3405687,23 1,21.6542582 1,19.9942017 L1,15.0057983 C1,13.3488159 2.34058566,12 3.99428189,12 L27.0057181,12 C28.6594313,12 30,13.3457418 30,15.0057983 L30,19.9942017 C30,21.6511841 28.6594143,23 27.0057181,23 L26,23 L26,20 L5,20 L5,23 L5,23 L5,23 Z M24,17 C24.5522848,17 25,16.5522848 25,16 C25,15.4477152 24.5522848,15 24,15 C23.4477152,15 23,15.4477152 23,16 C23,16.5522848 23.4477152,17 24,17 L24,17 Z M6,21 L6,29 L7,29 L7,21 L6,21 L6,21 Z M8,21 L8,28 L9,28 L9,21 L8,21 L8,21 Z M10,21 L10,29 L11,29 L11,21 L10,21 L10,21 Z M12,21 L12,27 L13,27 L13,21 L12,21 L12,21 Z M14,21 L14,28 L15,28 L15,21 L14,21 L14,21 Z M16,21 L16,27 L17,27 L17,21 L16,21 L16,21 Z M18,21 L18,29 L19,29 L19,21 L18,21 L18,21 Z M22,21 L22,28 L23,28 L23,21 L22,21 L22,21 Z M24,21 L24,29 L25,29 L25,21 L24,21 L24,21 Z M20,21 L20,27 L21,27 L21,21 L20,21 L20,21 Z" id="shredder"/></g></g></svg>
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
