defmodule ViralEngineWeb.StudySessionLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, StudySession, PracticeContext}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # Load study session by token
    study_session =
      from(ss in StudySession,
        where: ss.session_token == ^token
      )
      |> Repo.one()

    if study_session do
      if connected?(socket) do
        # Subscribe to study session updates
        Phoenix.PubSub.subscribe(ViralEngine.PubSub, "study_session:#{study_session.id}")
      end

      # Check if user is already a participant
      is_participant = user.id in study_session.participant_ids
      is_creator = study_session.creator_id == user.id

      socket =
        socket
        |> assign(:user, user)
        |> assign(:user_id, user.id)
        |> assign(:study_session, study_session)
        |> assign(:is_participant, is_participant)
        |> assign(:is_creator, is_creator)
        |> assign(:show_invite_modal, false)
        |> assign(:recommended_buddies, [])
        |> assign(:chat_messages, [])
        |> assign(:show_chat, false)
        |> assign(:new_message, "")

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Study session not found")
       |> redirect(to: "/dashboard")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    # List user's study sessions
    study_sessions =
      from(ss in StudySession,
        where: ss.creator_id == ^user.id or ^user.id in ss.participant_ids,
        where: ss.status in ["scheduled", "active"],
        order_by: [asc: ss.scheduled_at]
      )
      |> Repo.all()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:study_sessions, study_sessions)
      |> assign(:selected_session, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_session", _params, socket) do
    study_session = socket.assigns.study_session
    user_id = socket.assigns.user_id

    # Check if already participant
    if user_id in study_session.participant_ids do
      {:noreply,
       socket
       |> put_flash(:info, "You're already in this study session!")}
    else
      # Check if session is full
      if length(study_session.participant_ids) >= study_session.max_participants do
        {:noreply,
         socket
         |> put_flash(:error, "This study session is full")}
      else
        # Add user to participants
        updated_participants = [user_id | study_session.participant_ids]

        {:ok, updated_session} =
          Repo.update(
            StudySession.changeset(study_session, %{participant_ids: updated_participants})
          )

        # Broadcast join event
        Phoenix.PubSub.broadcast(
          ViralEngine.PubSub,
          "study_session:#{study_session.id}",
          {:user_joined, %{user_id: user_id}}
        )

        {:noreply,
         socket
         |> assign(:study_session, updated_session)
         |> assign(:is_participant, true)
         |> put_flash(:success, "You've joined the study session! 🎉")}
      end
    end
  end

  @impl true
  def handle_event("leave_session", _params, socket) do
    study_session = socket.assigns.study_session
    user_id = socket.assigns.user_id

    # Remove user from participants
    updated_participants = Enum.reject(study_session.participant_ids, &(&1 == user_id))

    {:ok, updated_session} =
      Repo.update(StudySession.changeset(study_session, %{participant_ids: updated_participants}))

    # Broadcast leave event
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "study_session:#{study_session.id}",
      {:user_left, %{user_id: user_id}}
    )

    {:noreply,
     socket
     |> assign(:study_session, updated_session)
     |> assign(:is_participant, false)
     |> put_flash(:info, "You've left the study session")}
  end

  @impl true
  def handle_event("open_invite_modal", _params, socket) do
    # Get recommended study buddies
    # In production, this would call StudyBuddyNudgeWorker.recommend_study_buddies/4
    recommended_buddies = []

    {:noreply,
     socket
     |> assign(:show_invite_modal, true)
     |> assign(:recommended_buddies, recommended_buddies)}
  end

  @impl true
  def handle_event("close_invite_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_modal, false)}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, :show_chat, !socket.assigns.show_chat)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      user = socket.assigns.user
      study_session = socket.assigns.study_session

      # Create message
      new_message = %{
        id: System.unique_integer([:positive]),
        user_id: user.id,
        user_name: "Student #{user.id}",
        content: String.trim(message),
        timestamp: DateTime.utc_now()
      }

      # Broadcast message
      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "study_session:#{study_session.id}",
        {:new_message, new_message}
      )

      # Add to local messages
      updated_messages = socket.assigns.chat_messages ++ [new_message]

      {:noreply,
       socket
       |> assign(:chat_messages, updated_messages)
       |> assign(:new_message, "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy_invite_link", _params, socket) do
    study_session = socket.assigns.study_session
    invite_url = study_session_url(study_session)

    Logger.info("Study session invite link copied: #{invite_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Invite link copied to clipboard!")}
  end

  @impl true
  def handle_event("start_practice", _params, socket) do
    study_session = socket.assigns.study_session

    # Create practice session for this study group
    {:ok, session} =
      PracticeContext.create_session(%{
        user_id: socket.assigns.user_id,
        session_type: "group_practice",
        subject: study_session.subject,
        metadata: %{
          study_session_id: study_session.id,
          study_session_token: study_session.session_token,
          topics: study_session.topics
        }
      })

    {:noreply,
     socket
     |> put_flash(:info, "Starting group practice session...")
     |> redirect(to: "/practice/#{session.id}")}
  end

  @impl true
  def handle_info({:user_joined, %{user_id: _joined_user_id}}, socket) do
    # Reload study session to get updated participant list
    study_session = Repo.get!(StudySession, socket.assigns.study_session.id)

    {:noreply,
     socket
     |> assign(:study_session, study_session)
     |> put_flash(:info, "Someone joined the study session!")}
  end

  @impl true
  def handle_info({:user_left, %{user_id: _left_user_id}}, socket) do
    # Reload study session
    study_session = Repo.get!(StudySession, socket.assigns.study_session.id)

    {:noreply,
     socket
     |> assign(:study_session, study_session)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Add message to chat
    updated_messages = socket.assigns.chat_messages ++ [message]

    {:noreply,
     socket
     |> assign(:chat_messages, updated_messages)}
  end

  # Helper functions

  defp study_session_url(study_session) do
    "#{ViralEngineWeb.Endpoint.url()}/study/#{study_session.session_token}"
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp participants_count(study_session) do
    length(study_session.participant_ids || [])
  end

  defp is_full?(study_session) do
    participants_count(study_session) >= study_session.max_participants
  end

  defp session_type_badge(session_type) do
    case session_type do
      "exam_prep" -> "Exam Prep"
      "homework_help" -> "Homework"
      "group_study" -> "Group Study"
      "tutoring" -> "Tutoring"
      _ -> "Study"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-5xl mx-auto">
        <%= if Map.has_key?(assigns, :study_session) do %>
          <!-- Study Session Details View -->
          <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-8 mb-6">
            <div class="flex items-center justify-between mb-6">
              <div>
                <div class="flex items-center space-x-3 mb-2">
                  <h1 class="text-3xl font-bold text-foreground"><%= @study_session.title %></h1>
                  <span class="px-3 py-1 bg-muted text-muted-foreground text-sm font-semibold rounded-full">
                    <%= session_type_badge(@study_session.session_type) %>
                  </span>
                </div>
                <p class="text-muted-foreground"><%= @study_session.description %></p>
              </div>
              <%= if @is_creator do %>
                <span class="px-4 py-2 bg-primary text-primary-foreground font-semibold rounded-md">
                  Creator
                </span>
              <% end %>
            </div>

            <!-- Session Info Cards -->
            <div class="grid md:grid-cols-4 gap-4 mb-6">
              <div class="bg-muted rounded-lg p-4 border">
                <p class="text-sm text-muted-foreground mb-1">Subject</p>
                <p class="text-lg font-bold text-foreground capitalize"><%= @study_session.subject %></p>
              </div>
              <div class="bg-muted rounded-lg p-4 border">
                <p class="text-sm text-muted-foreground mb-1">Participants</p>
                <p class="text-lg font-bold text-foreground">
                  <%= participants_count(@study_session) %>/<%= @study_session.max_participants %>
                </p>
              </div>
              <div class="bg-muted rounded-lg p-4 border">
                <p class="text-sm text-muted-foreground mb-1">Status</p>
                <p class="text-lg font-bold text-foreground capitalize"><%= @study_session.status %></p>
              </div>
              <div class="bg-muted rounded-lg p-4 border">
                <p class="text-sm text-muted-foreground mb-1">Scheduled</p>
                <p class="text-sm font-bold text-foreground">
                  <%= if @study_session.scheduled_at do %>
                    <%= format_datetime(@study_session.scheduled_at) %>
                  <% else %>
                    Not set
                  <% end %>
                </p>
              </div>
            </div>

            <!-- Topics -->
            <%= if @study_session.topics && length(@study_session.topics) > 0 do %>
              <div class="mb-6">
                <h3 class="text-sm font-medium text-foreground mb-2">Topics to Cover</h3>
                <div class="flex flex-wrap gap-2">
                  <%= for topic <- @study_session.topics do %>
                    <span class="px-3 py-1 bg-secondary text-secondary-foreground rounded-full text-sm font-medium">
                      <%= topic %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Action Buttons -->
            <div class="flex items-center space-x-3">
              <%= if @is_participant do %>
                <button
                  phx-click="start_practice"
                  class="flex-1 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md shadow-sm hover:shadow-md transition-all"
                  aria-label="Start group practice session"
                >
                  Start Group Practice
                </button>
                <%= if !@is_creator do %>
                  <button
                    phx-click="leave_session"
                    class="px-6 py-3 border border-destructive text-destructive hover:bg-destructive hover:text-destructive-foreground font-semibold rounded-md transition-colors"
                    aria-label="Leave study session"
                  >
                    Leave
                  </button>
                <% end %>
              <% else %>
                <%= if is_full?(@study_session) do %>
                  <button
                    disabled
                    class="flex-1 bg-muted text-muted-foreground font-semibold px-6 py-3 rounded-md cursor-not-allowed"
                    aria-label="Session is full"
                  >
                    Session Full
                  </button>
                <% else %>
                  <button
                    phx-click="join_session"
                    class="flex-1 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md shadow-sm hover:shadow-md transition-all"
                    aria-label="Join study session"
                  >
                    Join Study Session
                  </button>
                <% end %>
              <% end %>

              <%= if @is_creator || @is_participant do %>
                <button
                  phx-click="open_invite_modal"
                  class="px-6 py-3 bg-secondary text-secondary-foreground hover:bg-secondary/80 font-semibold rounded-md transition-colors"
                  aria-label="Invite friends to study session"
                >
                  Invite
                </button>
              <% end %>
            </div>
          </div>

          <!-- Participants List -->
          <%= if participants_count(@study_session) > 0 do %>
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6">
              <h2 class="text-xl font-bold text-foreground mb-4">
                Participants (<%= participants_count(@study_session) %>)
              </h2>
              <div class="grid md:grid-cols-3 gap-4">
                <%= for participant_id <- @study_session.participant_ids do %>
                  <div class="flex items-center space-x-3 p-3 bg-muted rounded-lg">
                    <div class="w-10 h-10 rounded-full bg-primary flex items-center justify-center text-primary-foreground font-bold">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                    </div>
                    <div class="flex-1">
                      <p class="font-medium text-foreground">
                        <%= if participant_id == @study_session.creator_id, do: "Creator - ", else: "" %>
                        Student <%= participant_id %>
                      </p>
                      <p class="text-xs text-green-600">● Active</p>
                    </div>
                  </div>
                <% end %>
              </div>
             </div>
           <% end %>

           <!-- Shared Progress Visualization -->
           <%= if @is_participant do %>
             <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 mb-6">
               <h2 class="text-xl font-bold text-foreground mb-4 flex items-center">
                 <svg class="w-6 h-6 mr-2 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                 </svg>
                 Group Progress
               </h2>
               <div class="space-y-4">
                 <!-- Overall Progress -->
                 <div>
                   <div class="flex items-center justify-between mb-2">
                     <span class="text-sm font-medium text-foreground">Session Progress</span>
                     <span class="text-sm text-muted-foreground">45%</span>
                   </div>
                   <div class="w-full bg-secondary rounded-full h-3 overflow-hidden">
                     <div class="h-3 bg-primary rounded-full transition-all duration-500" style="width: 45%"></div>
                   </div>
                 </div>

                 <!-- Individual Progress -->
                 <div class="grid md:grid-cols-2 gap-4">
                   <%= for participant_id <- @study_session.participant_ids do %>
                     <div class="bg-muted rounded-lg p-4 border">
                       <div class="flex items-center space-x-3 mb-3">
                         <div class="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground font-bold text-sm">
                           <%= String.first("Student #{participant_id}") %>
                         </div>
                         <div>
                           <p class="font-medium text-foreground">Student <%= participant_id %></p>
                           <p class="text-xs text-muted-foreground">Active now</p>
                         </div>
                       </div>
                       <div class="space-y-2">
                         <div class="flex items-center justify-between text-sm">
                           <span class="text-muted-foreground">Questions</span>
                           <span class="font-medium text-foreground">12/20</span>
                         </div>
                         <div class="w-full bg-background rounded-full h-2 overflow-hidden">
                           <div class="h-2 bg-green-500 rounded-full transition-all duration-500" style="width: 60%"></div>
                         </div>
                       </div>
                     </div>
                   <% end %>
                 </div>

                 <!-- Milestones -->
                 <div class="bg-muted rounded-lg p-4 border">
                   <h3 class="font-semibold text-foreground mb-3">Recent Milestones</h3>
                   <div class="space-y-2">
                     <div class="flex items-center space-x-2 text-sm">
                       <div class="w-2 h-2 rounded-full bg-green-500"></div>
                       <span class="text-foreground">Student 1 completed 10 questions</span>
                       <span class="text-muted-foreground">2 min ago</span>
                     </div>
                     <div class="flex items-center space-x-2 text-sm">
                       <div class="w-2 h-2 rounded-full bg-blue-500"></div>
                       <span class="text-foreground">Group reached 40% completion</span>
                       <span class="text-muted-foreground">5 min ago</span>
                     </div>
                   </div>
                 </div>
               </div>
             </div>
           <% end %>

           <!-- Chat Interface -->
           <%= if @is_participant do %>
             <div class="fixed bottom-6 right-6 z-40">
               <%= if @show_chat do %>
                 <div class="bg-card text-card-foreground rounded-lg border shadow-lg w-80 h-96 flex flex-col">
                   <div class="flex items-center justify-between p-4 border-b">
                     <h3 class="font-semibold text-foreground">Group Chat</h3>
                     <button
                       phx-click="toggle_chat"
                       class="text-muted-foreground hover:text-foreground"
                       aria-label="Close chat"
                     >
                       <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                       </svg>
                     </button>
                   </div>
                   <div class="flex-1 overflow-y-auto p-4 space-y-3" id="chat-messages">
                     <%= for message <- @chat_messages do %>
                       <div class="flex items-start space-x-2">
                         <div class="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-xs font-bold flex-shrink-0">
                           <%= String.first(message.user_name) %>
                         </div>
                         <div class="flex-1">
                           <div class="flex items-center space-x-2 mb-1">
                             <span class="text-sm font-medium text-foreground"><%= message.user_name %></span>
                             <span class="text-xs text-muted-foreground">
                               <%= Calendar.strftime(message.timestamp, "%H:%M") %>
                             </span>
                           </div>
                           <p class="text-sm text-foreground bg-muted rounded-lg px-3 py-2"><%= message.content %></p>
                         </div>
                       </div>
                     <% end %>
                   </div>
                   <div class="border-t p-4">
                     <form phx-submit="send_message" class="flex space-x-2">
                        <input
                          id="chat-input"
                          type="text"
                          name="message"
                          value={@new_message}
                          placeholder="Type a message..."
                          class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                          phx-hook="ChatInput"
                          aria-label="Chat message"
                        />
                       <button
                         type="submit"
                         class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                         aria-label="Send message"
                       >
                         Send
                       </button>
                     </form>
                   </div>
                 </div>
               <% else %>
                 <button
                   phx-click="toggle_chat"
                   class="bg-primary text-primary-foreground hover:bg-primary/90 rounded-full p-3 shadow-lg transition-all duration-200 hover:scale-110"
                   aria-label="Open group chat"
                 >
                   <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                   </svg>
                 </button>
               <% end %>
             </div>
           <% end %>
         <% else %>
          <!-- Study Sessions List View -->
          <div class="mb-6">
            <div class="flex items-center justify-between">
              <h1 class="text-4xl font-bold text-foreground">Study Together</h1>
              <a
                href="/study/new"
                class="bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-6 py-3 rounded-md shadow-sm hover:shadow-md transition-all"
                aria-label="Create new study session"
              >
                + New Session
              </a>
            </div>
            <p class="text-muted-foreground mt-2">Join or create collaborative study sessions with your friends</p>
          </div>

          <%= if length(@study_sessions) > 0 do %>
            <div class="grid md:grid-cols-2 gap-6">
              <%= for session <- @study_sessions do %>
                <a
                  href={"/study/#{session.session_token}"}
                  class="block bg-card text-card-foreground rounded-lg border shadow-sm p-6 hover:shadow-md transition-all duration-200 transform hover:scale-[1.02]"
                  aria-label={"View study session: #{session.title}"}
                >
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-xl font-bold text-foreground mb-2"><%= session.title %></h3>
                      <span class="inline-block px-3 py-1 bg-muted text-muted-foreground text-sm font-semibold rounded-full mb-2">
                        <%= session_type_badge(session.session_type) %>
                      </span>
                    </div>
                    <span class={"px-3 py-1 rounded-md font-semibold text-sm #{if session.status == "active", do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
                      <%= String.capitalize(session.status) %>
                    </span>
                  </div>

                  <p class="text-muted-foreground text-sm mb-4"><%= session.description %></p>

                  <div class="grid grid-cols-2 gap-3 mb-4">
                    <div class="flex items-center space-x-2 text-sm text-muted-foreground">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                      </svg>
                      <span class="capitalize"><%= session.subject %></span>
                    </div>
                    <div class="flex items-center space-x-2 text-sm text-muted-foreground">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                      <span><%= participants_count(session) %>/<%= session.max_participants %></span>
                    </div>
                  </div>

                  <%= if session.topics && length(session.topics) > 0 do %>
                    <div class="flex flex-wrap gap-2">
                      <%= for topic <- Enum.take(session.topics, 3) do %>
                        <span class="px-2 py-1 bg-secondary text-secondary-foreground rounded text-xs">
                          <%= topic %>
                        </span>
                      <% end %>
                    </div>
                  <% end %>
                </a>
              <% end %>
            </div>
          <% else %>
            <!-- Empty State -->
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-12 text-center">
              <div class="mx-auto flex items-center justify-center h-20 w-20 rounded-full bg-muted mb-4">
                <svg class="h-12 w-12 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-foreground mb-2">No Study Sessions Yet</h2>
              <p class="text-muted-foreground mb-6">Create or join a study session to start learning with friends!</p>
              <a
                href="/study/new"
                class="inline-block bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-8 py-3 rounded-md shadow-sm hover:shadow-md transition-all"
                aria-label="Create your first study session"
              >
                Create Study Session
              </a>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>

    <!-- Invite Modal -->
    <%= if Map.has_key?(assigns, :show_invite_modal) && @show_invite_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_invite_modal" role="dialog" aria-modal="true" aria-labelledby="invite-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="invite-modal-title" class="text-xl font-bold text-foreground mb-4">Invite Friends</h3>
          <p class="text-muted-foreground mb-6">Share this link to invite others to your study session</p>

          <div class="mb-6">
            <input
              type="text"
              value={study_session_url(@study_session)}
              readonly
              class="w-full px-3 py-2 bg-background border border-input rounded-md text-sm mb-3"
              aria-label="Study session invite link"
            />
            <button
              phx-click="copy_invite_link"
              class="w-full flex items-center justify-center space-x-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              aria-label="Copy invite link to clipboard"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <span>Copy Link</span>
            </button>
          </div>

          <button
            phx-click="close_invite_modal"
            class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
            aria-label="Close invite modal"
          >
            Close
          </button>
        </div>
      </div>
    <% end %>
    """
  end
end
