defmodule ViralEngine.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organizations" do
    field(:name, :string)
    field(:tenant_id, Ecto.UUID)
    field(:description, :string)
    # active, suspended, deleted
    field(:status, :string, default: "active")
    # JSONB for organization settings
    field(:settings, :map, default: %{})

    # Billing and limits
    field(:subscription_plan, :string, default: "free")
    field(:max_users, :integer, default: 10)
    field(:max_tasks_per_month, :integer, default: 1000)

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :tenant_id,
      :description,
      :status,
      :settings,
      :subscription_plan,
      :max_users,
      :max_tasks_per_month
    ])
    |> validate_required([:name, :tenant_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:status, ["active", "suspended", "deleted"])
    |> validate_inclusion(:subscription_plan, ["free", "pro", "enterprise"])
    |> validate_number(:max_users, greater_than: 0)
    |> validate_number(:max_tasks_per_month, greater_than: 0)
    |> unique_constraint(:tenant_id)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
