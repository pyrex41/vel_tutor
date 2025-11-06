defmodule ViralEngine.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:persona, :string, default: "student")
    field(:role, :string, default: "student")
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
      :persona,
      :role,
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

  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_length(:password, min: 6, max: 72)
    |> put_persona_from_role(attrs)
  end

  defp put_persona_from_role(changeset, attrs) do
    role = get_change(changeset, :role) || attrs["role"] || "student"

    persona = case role do
      "tutor" -> "tutor"
      "parent" -> "parent"
      _ -> "student"
    end

    put_change(changeset, :persona, persona)
  end
end
