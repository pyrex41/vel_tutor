defmodule ViralEngineWeb.PresenceView do
  use ViralEngineWeb, :view

  def render("index.json", %{users: users}) do
    %{data: Enum.map(users, &render("user.json", %{presence: &1}))}
  end

  def render("show.json", %{session: session}) do
    %{data: render("session.json", %{presence: session})}
  end

  def render("user.json", %{presence: session}) do
    %{
      id: session.user.id,
      username: session.user.username,
      display_name: session.user.display_name,
      avatar_url: session.user.avatar_url,
      status: session.status,
      current_activity: session.current_activity,
      subject_id: session.subject_id,
      last_seen_at: session.last_seen_at,
      connected_at: session.connected_at
    }
  end

  def render("session.json", %{presence: session}) do
    %{
      id: session.id,
      session_id: session.session_id,
      status: session.status,
      current_activity: session.current_activity,
      metadata: session.metadata,
      last_seen_at: session.last_seen_at,
      connected_at: session.connected_at
    }
  end

  def render("error.json", %{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end
end
