defmodule ViralEngine.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "achievements" do
    field :user_id, :integer
    field :achievement_type, :string
    field :achievement_name, :string
    field :description, :string
    field :icon_url, :string
    field :points, :integer, default: 0
    field :tier, :string
    field :unlocked_at, :utc_datetime
    field :shared, :boolean, default: false
    field :shared_at, :utc_datetime
    field :metadata, :map

    timestamps()
  end

  @doc false
  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [
      :user_id,
      :achievement_type,
      :achievement_name,
      :description,
      :icon_url,
      :points,
      :tier,
      :unlocked_at,
      :shared,
      :shared_at,
      :metadata
    ])
    |> validate_required([:user_id, :achievement_type, :achievement_name])
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> validate_inclusion(:tier, ["bronze", "silver", "gold", "platinum", "diamond"])
    |> foreign_key_constraint(:user_id)
  end
end
