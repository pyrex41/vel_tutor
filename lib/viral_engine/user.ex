defmodule ViralEngine.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:email, :string)
    field(:name, :string)
    belongs_to(:organization, ViralEngine.Organization)

    field(:last_seen_at, :utc_datetime)
    field(:presence_status, :string, default: "offline")
    field(:presence_opt_out, :boolean, default: false)

    # Many-to-many relationship with roles
    many_to_many(:roles, ViralEngine.Role, join_through: ViralEngine.UserRole)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :organization_id, :presence_opt_out])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end
end
