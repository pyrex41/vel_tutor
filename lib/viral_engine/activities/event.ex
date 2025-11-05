defmodule ViralEngine.Activities.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_events" do
    field(:event_type, :string)
    field(:data, :map, default: %{})
    field(:visibility, :string, default: "public")
    field(:reactions_count, :integer, default: 0)
    field(:subject_id, :integer)  # Will be converted to belongs_to when Subject schema exists

    belongs_to(:user, ViralEngine.Accounts.User)

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :subject_id, :event_type, :data, :visibility, :reactions_count])
    |> validate_required([:user_id, :event_type])
    |> validate_inclusion(:visibility, ["public", "private", "friends"])
  end
end
