defmodule ViralEngine.PresenceTracker do
  use GenServer

  alias ViralEngine.Presence
  alias ViralEngineWeb.Endpoint
  alias ViralEngine.Presences
  alias ViralEngine.Repo
  alias ViralEngine.Accounts.User

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  # GenServer API for server-side tracking
  def track_user(user_id, subject_id \\ nil, topic \\ nil, meta \\ %{}) do
    GenServer.call(__MODULE__, {:track, user_id, subject_id, topic, meta}, 30_000)
  end

  def untrack_user(user_id, subject_id \\ nil, topic \\ nil) do
    GenServer.call(__MODULE__, {:untrack, user_id, subject_id, topic}, 30_000)
  end

  def handle_call({:track, user_id, subject_id, topic, meta}, _from, state) do
    topic = topic || if subject_id, do: "subject:#{subject_id}", else: "global_users"

    # Log join event to presences table
    changeset =
      Presences.changeset(%Presences{}, %{
        user_id: user_id,
        topic: topic,
        event_type: "join",
        meta: Jason.encode!(meta)
      })

    {:ok, _} = Repo.insert(changeset)

    # Track in Phoenix Presence
    user = Repo.get(User, user_id)

    if user && user.presence_opt_out do
      Logger.info("User #{user_id} opted out of presence tracking")
    else
      if subject_id do
        Presence.track_subject(Endpoint, user_id, subject_id, meta)
      else
        Presence.track_global(Endpoint, user_id, meta)
      end
    end

    # Update user status only if not opted out
    case Repo.get(User, user_id) do
      nil ->
        Logger.warning("User #{user_id} not found for presence tracking")

      user ->
        if user.presence_opt_out do
          Repo.update!(Ecto.Changeset.change(user, last_seen_at: DateTime.utc_now()))
        else
          Repo.update!(
            Ecto.Changeset.change(user,
              presence_status: "online",
              last_seen_at: DateTime.utc_now()
            )
          )
        end
    end

    {:reply, :ok, state}
  end

  def handle_call({:untrack, user_id, subject_id, topic}, _from, state) do
    topic = topic || if subject_id, do: "subject:#{subject_id}", else: "global_users"

    # Log leave event
    changeset =
      Presences.changeset(%Presences{}, %{
        user_id: user_id,
        topic: topic,
        event_type: "leave",
        meta: Jason.encode!(%{})
      })

    {:ok, _} = Repo.insert(changeset)

    # Untrack from presence
    if subject_id do
      subject_topic = "subject:#{subject_id}"
      Presence.untrack(Endpoint, subject_topic, user_id)

      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "presence:subject:#{subject_id}",
        {:presence_diff, {subject_topic, nil}}
      )
    else
      Presence.untrack(Endpoint, "global_users", user_id)

      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "presence:global",
        {:presence_diff, {"global_users", nil}}
      )
    end

    # Update user status
    case Repo.get(User, user_id) do
      nil ->
        Logger.warning("User #{user_id} not found for presence untracking")

      user ->
        Repo.update!(
          Ecto.Changeset.change(user,
            presence_status: "offline",
            last_seen_at: DateTime.utc_now()
          )
        )
    end

    {:reply, :ok, state}
  end

  # Socket-based tracking for LiveView connections
  def track_socket(socket, user, opts \\ []) when is_list(opts) do
    subject_id = Keyword.get(opts, :subject_id)

    if user.presence_opt_out do
      # Update last_seen_at even if opted out
      Repo.update!(Ecto.Changeset.change(user, last_seen_at: DateTime.utc_now()))
      socket
    else
      # Global tracking
      meta_global = %{
        online_at: DateTime.utc_now(),
        role: user.role,
        user_id: user.id
      }

      Presence.track(socket, "global_users", user.id, meta_global)

      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "presence:global",
        {:presence_diff, {"global_users", nil}}
      )

      track_user(user.id, nil, "global_users", meta_global)

      # Subject-specific tracking if provided
      if subject_id do
        meta_subject = Map.put(meta_global, :subject_id, subject_id)
        subject_topic = "subject:#{subject_id}"
        Presence.track(socket, subject_topic, user.id, meta_subject)

        Phoenix.PubSub.broadcast(
          ViralEngine.PubSub,
          "presence:subject:#{subject_id}",
          {:presence_diff, {subject_topic, nil}}
        )

        track_user(user.id, subject_id, subject_topic, meta_subject)
      end

      socket
    end
  end

  def untrack_socket(socket, user, opts \\ []) do
    subject_id = Keyword.get(opts, :subject_id)

    # Global untrack
    Presence.untrack(socket, "global_users", user.id)

    start_time = System.monotonic_time(:millisecond)

    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "presence:global",
      {:presence_diff, {"global_users", nil}}
    )

    latency = System.monotonic_time(:millisecond) - start_time
    ViralEngine.Metrics.record_presence_broadcast("global", latency)

    untrack_user(user.id, nil, "global_users")

    # Subject untrack
    if subject_id do
      subject_topic = "subject:#{subject_id}"
      Presence.untrack(socket, subject_topic, user.id)

      Phoenix.PubSub.broadcast(
        ViralEngine.PubSub,
        "presence:subject:#{subject_id}",
        {:presence_diff, {subject_topic, nil}}
      )

      untrack_user(user.id, subject_id, subject_topic)
    end

    # Update user status
    Repo.update!(
      Ecto.Changeset.change(user, presence_status: "offline", last_seen_at: DateTime.utc_now())
    )

    socket
  end

  def list_presence(topic) do
    Presence.list(topic)
  end

  def get_recent_presences(user_id, limit \\ 100) do
    import Ecto.Query

    query =
      from(p in Presences,
        where: p.user_id == ^user_id,
        order_by: [desc: p.inserted_at],
        limit: ^limit
      )

    Repo.all(query)
  end
end
