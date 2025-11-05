defmodule ViralEngineWeb.PresenceController do
  use ViralEngineWeb, :controller
  alias ViralEngine.PresenceTracking

  def index(conn, %{"subject_id" => subject_id}) do
    online_users = PresenceTracking.get_online_users(subject_id)
    render(conn, "index.json", users: online_users)
  end

  def index(conn, _params) do
    online_users = PresenceTracking.get_online_users()
    render(conn, "index.json", users: online_users)
  end

  def update_status(conn, %{"status" => status}) do
    _user_id = conn.assigns.current_user.id
    session_id = get_session_id(conn)

    case PresenceTracking.update_session(session_id, %{
           status: status,
           last_seen_at: DateTime.utc_now()
         }) do
      {:ok, session} ->
        render(conn, "show.json", session: session)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  def update_activity(conn, %{"activity" => activity}) do
    _user_id = conn.assigns.current_user.id
    session_id = get_session_id(conn)

    case PresenceTracking.update_session(session_id, %{
           current_activity: activity,
           last_seen_at: DateTime.utc_now()
         }) do
      {:ok, session} ->
        render(conn, "show.json", session: session)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", changeset: changeset)
    end
  end

  defp get_session_id(conn) do
    # Generate or retrieve session ID from connection
    # In a real implementation, this would be stored in session or JWT
    user_id = conn.assigns.current_user.id
    "user_session_#{user_id}"
  end
end
