defmodule ViralEngine.TutoringSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tutoring_sessions" do
    field :student_id, :integer
    field :tutor_id, :integer
    field :subject, :string
    field :topic, :string
    field :duration_minutes, :integer
    field :rating, :integer
    field :feedback, :string
    field :transcript_url, :string
    field :transcript_text, :string
    field :summary, :string
    field :ai_summary, :string
    field :student_actions, :map
    field :tutor_actions, :map
    field :parent_actions, :map
    field :processed, :boolean, default: false
    field :processed_at, :utc_datetime
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(tutoring_session, attrs) do
    tutoring_session
    |> cast(attrs, [
      :student_id,
      :tutor_id,
      :subject,
      :topic,
      :duration_minutes,
      :rating,
      :feedback,
      :transcript_url,
      :transcript_text,
      :summary,
      :ai_summary,
      :student_actions,
      :tutor_actions,
      :parent_actions,
      :processed,
      :processed_at,
      :started_at,
      :ended_at
    ])
    |> validate_required([:student_id, :tutor_id])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:duration_minutes, greater_than: 0)
    |> foreign_key_constraint(:student_id)
    |> foreign_key_constraint(:tutor_id)
  end
end
