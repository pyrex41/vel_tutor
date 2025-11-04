defmodule ViralEngine.Repo.Migrations.AddTenantIdToRateLimits do
  use Ecto.Migration

  def change do
    alter table(:rate_limits) do
      add(:tenant_id, :binary_id, null: false)
    end

    # Drop old unique indexes
    drop(unique_index(:rate_limits, [:user_id]))
    drop(unique_index(:rate_limits, [:organization_id]))

    # Create new composite unique indexes
    create(unique_index(:rate_limits, [:tenant_id, :user_id]))
    create(unique_index(:rate_limits, [:tenant_id, :organization_id]))
  end
end
