defmodule ViralEngine.Activities.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_reactions" do
    field(:reaction, :string)

    belongs_to(:activity_event, ViralEngine.Activities.Event)
    belongs_to(:user, ViralEngine.Accounts.User)

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:activity_event_id, :user_id, :reaction])
    |> validate_required([:activity_event_id, :user_id, :reaction])
    |> unique_constraint([:activity_event_id, :user_id])
  end
end
