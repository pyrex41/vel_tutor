defmodule ViralEngine.WeeklyRecap do
  use Ecto.Schema
  import Ecto.Changeset

  schema "weekly_recaps" do
    field :parent_id, :integer
    field :student_id, :integer
    field :week_start, :date
    field :week_end, :date
    field :session_count, :integer, default: 0
    field :total_minutes, :integer, default: 0
    field :skills_practiced, {:array, :string}, default: []
    field :improvements, :map
    field :highlights, :string
    field :progress_reel_url, :string
    field :shared, :boolean, default: false
    field :shared_at, :utc_datetime
    field :share_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(weekly_recap, attrs) do
    weekly_recap
    |> cast(attrs, [
      :parent_id,
      :student_id,
      :week_start,
      :week_end,
      :session_count,
      :total_minutes,
      :skills_practiced,
      :improvements,
      :highlights,
      :progress_reel_url,
      :shared,
      :shared_at,
      :share_count
    ])
    |> validate_required([:parent_id, :student_id, :week_start, :week_end])
    |> validate_number(:session_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:share_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:student_id)
  end
end
