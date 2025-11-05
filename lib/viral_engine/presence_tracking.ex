defmodule ViralEngine.PresenceTracking do
  import Ecto.Query
  alias ViralEngine.Repo
  alias ViralEngine.PresenceTracking.Session

  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(session_id, attrs) do
    get_session!(session_id)
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def get_session!(session_id) do
    Repo.get_by!(Session, session_id: session_id)
  end

  def get_online_users(subject_id \\ nil) do
    cutoff = DateTime.add(DateTime.utc_now(), -5, :minute)

    query =
      from(s in Session,
        where: is_nil(s.left_at) and (is_nil(s.last_seen_at) or s.last_seen_at > ^cutoff),
        preload: [:user]
      )

    query =
      if subject_id do
        where(query, [s], s.subject_id == ^subject_id)
      else
        query
      end

    Repo.all(query)
  end

  def cleanup_stale_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -10, :minute)

    from(s in Session,
      where: is_nil(s.left_at) and s.last_seen_at < ^cutoff
    )
    |> Repo.update_all(set: [left_at: DateTime.utc_now()])
  end

  def get_user_sessions(user_id) do
    from(s in Session,
      where: s.user_id == ^user_id and is_nil(s.left_at)
    )
    |> Repo.all()
  end

  def disconnect_session(session_id) do
    case Repo.get_by(Session, session_id: session_id) do
      nil ->
        {:error, :not_found}

      session ->
        session
        |> Session.changeset(%{left_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end
end
