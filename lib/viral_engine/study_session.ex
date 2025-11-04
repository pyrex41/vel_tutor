defmodule ViralEngine.StudySession do
  @moduledoc """
  Schema for group study sessions.

  Represents collaborative study sessions where multiple users
  can practice together, share insights, and help each other.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "study_sessions" do
    field(:creator_id, :integer)
    field(:session_name, :string)
    field(:subject, :string)
    field(:grade_level, :integer)

    field(:session_token, :string)
    field(:scheduled_at, :utc_datetime)
    field(:duration_minutes, :integer, default: 60)

    field(:status, :string, default: "scheduled")
    # scheduled, active, completed, cancelled

    field(:participant_ids, {:array, :integer}, default: [])
    field(:max_participants, :integer, default: 6)

    field(:session_type, :string, default: "group_practice")
    # group_practice, exam_prep, peer_tutoring

    field(:topics, {:array, :string}, default: [])
    field(:exam_date, :date)  # If exam prep session

    field(:metadata, :map, default: %{})

    timestamps()
  end

  def changeset(study_session, attrs) do
    study_session
    |> cast(attrs, [
      :creator_id,
      :session_name,
      :subject,
      :grade_level,
      :session_token,
      :scheduled_at,
      :duration_minutes,
      :status,
      :participant_ids,
      :max_participants,
      :session_type,
      :topics,
      :exam_date,
      :metadata
    ])
    |> validate_required([:creator_id, :session_name, :subject, :session_token])
    |> validate_inclusion(:status, ["scheduled", "active", "completed", "cancelled"])
    |> validate_inclusion(:session_type, ["group_practice", "exam_prep", "peer_tutoring"])
    |> unique_constraint(:session_token)
  end

  @doc """
  Generates a unique session token.
  """
  def generate_token(creator_id, subject) do
    :crypto.hash(:sha256, "#{creator_id}-#{subject}-#{System.system_time(:microsecond)}")
    |> Base.url_encode64()
    |> binary_part(0, 32)
  end
end
