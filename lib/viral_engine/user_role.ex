defmodule ViralEngine.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  @foreign_key_type :binary_id
  schema "user_roles" do
    belongs_to(:user, ViralEngine.User)
    belongs_to(:role, ViralEngine.Role)
    belongs_to(:organization, ViralEngine.Organization)
    field(:assigned_at, :utc_datetime)

    timestamps()
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :organization_id, :assigned_at])
    |> validate_required([:user_id, :role_id, :organization_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :role_id, :organization_id])
  end
end
