defmodule ViralEngine.Presence do
  use Phoenix.Presence,
    otp_app: :viral_engine,
    pubsub_server: ViralEngine.PubSub

  alias ViralEngine.Accounts

  def track_global(socket, user_id, meta \\ %{}) do
    user = Accounts.get_user!(user_id)

    unless user.presence_opt_out do
      track(
        socket,
        "global_users",
        user_id,
        meta
        |> Map.put(:name, user.name || "Anonymous")
        |> Map.put(:user_id, user_id)
      )

      # Create/update presence session
      session_id = "global_#{user_id}_#{:erlang.system_time(:second)}"

      ViralEngine.PresenceTracking.create_session(%{
        user_id: user_id,
        session_id: session_id,
        status: meta[:status] || "online",
        current_activity: meta[:current_activity],
        metadata: meta,
        last_seen_at: DateTime.utc_now(),
        connected_at: DateTime.utc_now()
      })

      ViralEngine.PresenceTracker.track_user(user_id, nil, "global_users", meta)
    end
  end

  def track_subject(socket, user_id, subject_id, meta \\ %{}) do
    user = Accounts.get_user!(user_id)

    unless user.presence_opt_out do
      topic = "subject:#{subject_id}"

      track(
        socket,
        topic,
        user_id,
        meta
        |> Map.put(:name, user.name || "Anonymous")
        |> Map.put(:user_id, user_id)
      )

      # Create/update presence session
      session_id = "subject_#{subject_id}_#{user_id}_#{:erlang.system_time(:second)}"

      ViralEngine.PresenceTracking.create_session(%{
        user_id: user_id,
        subject_id: subject_id,
        session_id: session_id,
        status: meta[:status] || "online",
        current_activity: meta[:current_activity],
        metadata: meta,
        last_seen_at: DateTime.utc_now(),
        connected_at: DateTime.utc_now()
      })

      ViralEngine.PresenceTracker.track_user(user_id, subject_id, topic, meta)
    end
  end

  def list_global do
    list("global_users")
    |> Enum.filter(fn {_, meta} ->
      case Integer.parse(meta.user_id || "0") do
        {user_id, _} ->
          user = Accounts.get_user!(user_id)
          not user.presence_opt_out

        _ ->
          false
      end
    end)
  end

  def list_subject(subject_id) do
    topic = "subject:#{subject_id}"

    list(topic)
    |> Enum.filter(fn {_, meta} ->
      case Integer.parse(meta.user_id || "0") do
        {user_id, _} ->
          user = Accounts.get_user!(user_id)
          not user.presence_opt_out

        _ ->
          false
      end
    end)
  end

  def fetch(_topic, {metas, _}) do
    filtered_metas =
      Enum.filter(metas, fn {_, meta} ->
        case Integer.parse(meta.user_id || "0") do
          {user_id, _} ->
            user = Accounts.get_user!(user_id)
            not user.presence_opt_out

          _ ->
            false
        end
      end)

    {:ok, filtered_metas}
  end

  def track_user_presence(user, socket) do
    user_id = user.id
    subject = get_subject_for_user(user)
    track_global(socket, user_id, %{})
    track_subject(socket, user_id, subject, %{})
  end

  defp get_subject_for_user(_user) do
    "general"
  end
end
