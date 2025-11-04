defmodule ViralEngine.Activity.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activities" do
    field(:type, :string)
    field(:content, :string)
    field(:target_id, :id)
    field(:target_type, :string)

    belongs_to(:user, ViralEngine.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:type, :content, :user_id, :target_id, :target_type])
    |> validate_required([:type, :user_id])
    |> assoc_constraint(:user)
  end
end
