defmodule ViralEngine.PresenceTracking.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presences" do
    field(:topic, :string)
    field(:event_type, :string)
    field(:meta, :string)
    field(:joined_at, :utc_datetime)
    field(:left_at, :utc_datetime)
    field(:subject_id, :integer)
    field(:session_id, :string)
    field(:status, :string, default: "online")
    field(:current_activity, :string)
    field(:metadata, :map, default: %{})
    field(:last_seen_at, :utc_datetime)

    belongs_to(:user, ViralEngine.Accounts.User)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :topic,
      :event_type,
      :meta,
      :subject_id,
      :session_id,
      :status,
      :current_activity,
      :metadata,
      :last_seen_at,
      :joined_at
    ])
    |> validate_required([:user_id, :topic, :event_type, :session_id, :last_seen_at])
    |> validate_inclusion(:status, ["online", "away", "studying", "in_quiz"])
    |> unique_constraint(:session_id)
  end
end
