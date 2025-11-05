defmodule ViralEngine.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:presence_opt_out, :boolean, default: false)
    field(:activity_opt_out, :boolean, default: false)
    field(:presence_status, :string, default: "offline")
    field(:last_seen_at, :utc_datetime)
    field(:session_token, :string)

    timestamps()

    has_many(:presences, ViralEngine.Presences)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :presence_opt_out,
      :activity_opt_out,
      :presence_status,
      :last_seen_at,
      :session_token
    ])
    |> validate_required([:email, :name])
    |> unique_constraint(:email)
    |> unique_constraint(:session_token)
  end
end
