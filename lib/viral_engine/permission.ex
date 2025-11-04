defmodule ViralEngine.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "permissions" do
    field(:name, :string)
    field(:description, :string)

    # Many-to-many relationship with roles
    many_to_many(:roles, ViralEngine.Role, join_through: "roles_permissions")

    timestamps()
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:name)
  end
end
