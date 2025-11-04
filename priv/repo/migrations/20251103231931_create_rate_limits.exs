defmodule ViralEngine.Repo.Migrations.CreateRateLimits do
  use Ecto.Migration

  def change do
    create table(:rate_limits, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all))
      add(:tasks_per_hour, :integer, default: 100, null: false)
      add(:concurrent_tasks, :integer, default: 5, null: false)
      add(:current_hourly_count, :integer, default: 0, null: false)
      add(:current_concurrent_count, :integer, default: 0, null: false)

      timestamps()
    end

    # Ensure either user_id or organization_id is provided, but not both
    create(
      constraint(:rate_limits, :rate_limits_user_or_org_check,
        check:
          "(user_id IS NOT NULL AND organization_id IS NULL) OR (user_id IS NULL AND organization_id IS NOT NULL)"
      )
    )

    # Unique indexes (these also create indexes for performance)
    create(unique_index(:rate_limits, [:user_id]))
    create(unique_index(:rate_limits, [:organization_id]))
  end
end
