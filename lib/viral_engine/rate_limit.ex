defmodule ViralEngine.RateLimit do
  @moduledoc """
  Rate limit schema for customizable rate limits per user or organization.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "rate_limits" do
    field(:tenant_id, Ecto.UUID)
    field(:user_id, :id)
    field(:organization_id, :binary_id)
    field(:tasks_per_hour, :integer, default: 100)
    field(:concurrent_tasks, :integer, default: 5)
    field(:current_hourly_count, :integer, default: 0)
    field(:current_concurrent_count, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(rate_limit, attrs) do
    rate_limit
    |> cast(attrs, [
      :tenant_id,
      :user_id,
      :organization_id,
      :tasks_per_hour,
      :concurrent_tasks,
      :current_hourly_count,
      :current_concurrent_count
    ])
    |> validate_required([:tenant_id, :tasks_per_hour, :concurrent_tasks])
    |> validate_number(:tasks_per_hour, greater_than: 0)
    |> validate_number(:concurrent_tasks, greater_than: 0)
    |> validate_number(:current_hourly_count, greater_than_or_equal_to: 0)
    |> validate_number(:current_concurrent_count, greater_than_or_equal_to: 0)
    |> check_constraint(:user_id,
      name: "rate_limits_user_or_org_check",
      message: "Either user_id or organization_id must be provided"
    )
    |> check_constraint(:organization_id,
      name: "rate_limits_user_or_org_check",
      message: "Either user_id or organization_id must be provided"
    )
    |> unique_constraint([:tenant_id, :user_id], name: "rate_limits_tenant_user_id_index")
    |> unique_constraint([:tenant_id, :organization_id],
      name: "rate_limits_tenant_organization_id_index"
    )
  end
end
