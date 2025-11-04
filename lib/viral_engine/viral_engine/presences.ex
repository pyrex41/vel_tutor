defmodule ViralEngine.ViralEngine.Presences do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presences" do
    field(:joined_at, :utc_datetime)
    field(:left_at, :utc_datetime)
    field(:topic, :string)
    field(:user_id, :id)

    timestamps()
  end

  @doc false
  def changeset(presences, attrs) do
    presences
    |> cast(attrs, [:topic, :joined_at, :left_at])
    |> validate_required([:topic, :joined_at, :left_at])
  end
end
