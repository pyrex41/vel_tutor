defmodule ViralEngineWeb.DashboardLive do
  use ViralEngineWeb, :live_view

  alias ViralEngine.Presence
  alias ViralEngine.Accounts
  alias ViralEngine.PresenceTracker

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      Presence.track_global(user.id, socket)
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:global")
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "presence:subjects")
    end

    {:ok,
     assign(socket,
       user: user,
       global_count: Presence.list_global(),
       subject_counts: %{"math" => 0, "science" => 0}
     )}
  end

  @impl true
  def handle_info({:presence_diff, topic, _diff}, socket) do
    case topic do
      "global" ->
        global_count = Presence.list_global()
        {:noreply, assign(socket, global_count: global_count)}

      "subject:" <> subject ->
        subject_count = Presence.list_subject(subject)
        current_counts = socket.assigns.subject_counts
        updated_counts = Map.put(current_counts, subject, subject_count)
        {:noreply, assign(socket, subject_counts: updated_counts)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_opt_out", _params, socket) do
    user = socket.assigns.user
    new_opt_out = !user.presence_opt_out
    {:ok, updated_user} = Accounts.update_user(user, %{presence_opt_out: new_opt_out})

    if new_opt_out do
      PresenceTracker.untrack_user(user.id, nil, "global_users")
    else
      Presence.track_global(self(), user.id, %{name: user.name || "Anonymous"})
    end

    {:noreply, assign(socket, user: updated_user)}
  end

  @impl true
  def handle_event("join_subject", %{"subject" => subject}, socket) do
    user_id = socket.assigns.user.id

    Presence.track_subject(self(), user_id, subject, %{
      name: socket.assigns.user.name || "Anonymous"
    })

    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "presence:subjects",
      {:presence_diff, "subject:#{subject}", %{}}
    )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>Dashboard</h1>
      <div class="opt-out-section">
        <label>
          <input type="checkbox" phx-click="toggle_opt_out" checked={@user.presence_opt_out}>
          Opt out of presence tracking
        </label>
      </div>
      <div class="presence-section">
        <.live_component module={ViralEngineWeb.GlobalPresenceLive} id="global-presence" />
        <.live_component module={ViralEngineWeb.SubjectPresenceLive} id="math-presence" subject_id="math" />
        <.live_component module={ViralEngineWeb.SubjectPresenceLive} id="science-presence" subject_id="science" />
      </div>
      <div class="action-buttons">
        <button phx-click="join_subject" phx-value-subject="math">Join Math</button>
        <button phx-click="join_subject" phx-value-subject="science">Join Science</button>
      </div>
    </div>
    """
  end
end
