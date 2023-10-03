defmodule CricketsWeb.ChatLive do
  @moduledoc """
  This is the live component powering chat functionality.
  At a high level, this functionality encompasses:
  * Seeing which friends are currently online
  * Chatting with friends
  * Saving chats to local storage to preserve continuity without storing chat messages on the backend.
  """

  require Logger
  use CricketsWeb, :live_view

  alias CricketsWeb.Presence # used to track which friends are online
  alias Crickets.ChatMessage # named struct holding a single chat message

  # Topic to track which users are online
  @online_users_presence_topic "crickets:online_users_presence_topic"


  @doc """
  Invoked when the user either comes to `/chat` for the first time, or refreshes the page, or if the backend restarts.
  """
  @impl true
  def mount(_params, _session, socket) do
    me = socket.assigns.current_user.handle

    # Track me so that my friends can see when I'm online.
    Presence.track(
      self(),
      @online_users_presence_topic,
      me,
      %{}
    )

    # Interested in messages directed at me. Each user has a topic named after his/her handle.
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


  @doc """
  Requesting the browser for the previous state to restore from.
  See: https://fly.io/phoenix-files/saving-and-restoring-liveview-state/
  """
  @impl true
  def handle_params(_params, _, socket) do
    # Only try to talk to the client when the websocket is setup. Not on the initial "static" render.
    new_socket =
      if connected?(socket) do
        socket
        # request the browser to restore any state it has for me.
        |> push_event("restore", %{key: socket.assigns.me, event: "restoreSettings"})
      else
        socket
      end

    {:noreply, new_socket}
  end


  @impl true
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
        <form phx-submit="send-message-click" class="msg-input-container">
          <textarea
            id={"#{@outbound_message_count}"}
            name="messageInput"
            class="msg-input"
            phx-keydown="send-message"
            phx-key="Enter"
            phx-hook="Focus"
          />
          <button type="submit" class="msg-send-button">Send</button>
        </form>
        <%!-- Conversations --%>
        <div
          class="msg-page"
        >
          <%= if @chats && @chats[@currently_chatting_with] do %>
            <%= for {chat, i} <- Enum.with_index(@chats[@currently_chatting_with]) do %>
              <%= if i < 100 do %>
                <p
                  class={"#{if(chat.from == @me, do: "my-message", else: "friends-message")} #{if(i == 0, do: "latest-message")}"}
                  style={"opacity: #{1.0 - i * 0.01}"}
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

  # Invoked when the user clicks `Send`.
  @impl true
  def handle_event("send-message-click", %{"messageInput" => message}, socket) do
    {:noreply, send_message(message, socket)}
  end

  # Invoked when the user hits `Enter` in the chat box.
  @impl true
  def handle_event("send-message", %{"value" => message}, socket) do
    {:noreply, send_message(message, socket)}
  end


  # Invoked when the user clicks on a friend.
  def handle_event("friend-clicked", %{"friend-name" => friend}, socket) do
    {
      :noreply,
      socket
      |> assign(:currently_chatting_with, friend)
      |> update(:voicemail, fn _ -> Map.delete(socket.assigns.voicemail, friend) end)
    }
  end


  # Sent by the JS hook `LocalStateStore` in response to the server having asked to restore state.
  # See: https://fly.io/phoenix-files/saving-and-restoring-liveview-state/
  def handle_event("restoreSettings", token_data, socket) when is_binary(token_data) do
    socket =
      case restore_from_token(token_data) do
        {:ok, nil} ->
          # do nothing with the previous state
          socket

        {:ok, restored} ->
          socket
          |> assign(:chats, restored) # TODO actually merge the chats

        {:error, _reason} ->
          # Clear the token so it doesn't keep showing an error.
          socket
          |> clear_browser_storage()
      end

    {:noreply, socket}
  end


  # Sent by the JS hook `LocalStateStore` in response to the server having asked to restore state.
  # See: https://fly.io/phoenix-files/saving-and-restoring-liveview-state/
  def handle_event("restoreSettings", _token_data, socket) do
    # No expected token data received from the client
    Logger.debug("No LiveView SessionStorage state to restore")
    {:noreply, socket}
  end


  # Incoming chat message
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "chat", payload: payload}, socket) do
    chat_message = Jason.decode!(payload)

    {
      :noreply,
      socket
      |> handle_new_chat_message(%ChatMessage{
        from:     Map.get(chat_message, "from"),
        to:       Map.get(chat_message, "to"),
        message:  Map.get(chat_message, "message"),
        at:       Map.get(chat_message, "at")
      })
    }
  end


  # There's been a change to who's online.
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {
      :noreply,
      socket
      |> assign(:friends, Presence.list(@online_users_presence_topic)) # TODO this will get expensive as number of users increases
    }
  end


  defp send_message(message, socket) do
    if String.length(message) == 0 do
      socket
    else
      chat_message = %ChatMessage{
        :from => socket.assigns.me,
        :to => socket.assigns.currently_chatting_with,
        :message => message,
        :at => DateTime.utc_now()
      }

      # Send the chat out to the recipient
      CricketsWeb.Endpoint.broadcast!(chat_message.to, "chat", Jason.encode!(chat_message))

      if chat_message.from != chat_message.to do
        socket
        |> assign(:outbound_message_count, 1 + socket.assigns.outbound_message_count)
        |> handle_new_chat_message(chat_message) # don't want duplicate messages when chatting with yourself
      else
        socket
        |> assign(:outbound_message_count, 1 + socket.assigns.outbound_message_count)
      end
    end
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

    socket
    |> update(:chats, fn _ -> chats end)
    |> update(:voicemail, fn _ -> voicemail end)
    |> push_event("store", %{
      key:  socket.assigns.me,
      data: serialize_to_token(chats) # TODO we ought to version this data
    }) # TODO ideally this goes into a liveview lifecycle hook just before the process is killed
    # But.. "Note: only :after_render hooks are currently supported in LiveComponents."
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#attach_hook/4
  end

  defp restore_from_token(token) do
    salt = Application.get_env(:crickets, CricketsWeb.Endpoint)[:live_view][:signing_salt]

    # Max age is 7 days. 86,400 seconds * 7
    # TODO we should really embed version number into the token
    case Phoenix.Token.decrypt(CricketsWeb.Endpoint, salt, token, max_age: 86_400 * 7) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} ->
        # handles `:invalid`, `:expired` and possibly other things?
        {:error, "Failed to restore previous state. Reason: #{inspect(reason)}."}
    end
  end


  defp serialize_to_token(state_data) do
    salt = Application.get_env(:crickets, CricketsWeb.Endpoint)[:live_view][:signing_salt]
    Phoenix.Token.encrypt(CricketsWeb.Endpoint, salt, state_data)
  end


  # Push a websocket event down to the browser's JS hook to clear any chat data.
  defp clear_browser_storage(socket) do
    push_event(socket, "clear", %{key: socket.assigns.me})
  end
end
