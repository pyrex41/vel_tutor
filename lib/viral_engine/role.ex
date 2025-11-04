defmodule ViralEngine.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "roles" do
    field(:name, :string)
    field(:description, :string)

    # Many-to-many relationship with permissions
    many_to_many(:permissions, ViralEngine.Permission, join_through: "roles_permissions")

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:name)
  end
end
