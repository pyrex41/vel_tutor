defmodule ViralEngine.Presences do
  use Ecto.Schema
  import Ecto.Changeset

  schema "presences" do
    field(:topic, :string)
    field(:event_type, :string)
    field(:meta, :string)
    belongs_to(:user, ViralEngine.Accounts.User)

    timestamps()
  end

  def changeset(presence, attrs) do
    presence
    |> cast(attrs, [:user_id, :topic, :event_type, :meta])
    |> validate_required([:user_id, :topic, :event_type])
    |> assoc_constraint(:user)
  end
end
