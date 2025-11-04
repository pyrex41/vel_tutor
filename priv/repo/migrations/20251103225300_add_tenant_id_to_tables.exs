defmodule ViralEngine.Repo.Migrations.AddTenantIdToTables do
  use Ecto.Migration

  def change do
    # Add tenant_id to workflows table
    alter table(:workflows) do
      add(:tenant_id, :uuid, null: false, default: fragment("gen_random_uuid()"))
    end

    # Add tenant_id to agents table
    alter table(:agents) do
      add(:tenant_id, :uuid, null: false, default: fragment("gen_random_uuid()"))
    end

    # Add tenant_id to benchmarks table
    alter table(:benchmarks) do
      add(:tenant_id, :uuid, null: false, default: fragment("gen_random_uuid()"))
    end

    # Add tenant_id to alerts table
    alter table(:alerts) do
      add(:tenant_id, :uuid, null: false, default: fragment("gen_random_uuid()"))
    end

    # Add tenant_id to metrics table
    alter table(:metrics) do
      add(:tenant_id, :uuid, null: false, default: fragment("gen_random_uuid()"))
    end

    # Create indexes for tenant_id on all tables
    create(index(:workflows, [:tenant_id]))
    create(index(:agents, [:tenant_id]))
    create(index(:benchmarks, [:tenant_id]))
    create(index(:alerts, [:tenant_id]))
    create(index(:metrics, [:tenant_id]))

    # Create composite indexes for common queries
    create(index(:workflows, [:tenant_id, :status]))
    create(index(:agents, [:tenant_id, :user_id]))
    create(index(:alerts, [:tenant_id, :status]))
    create(index(:metrics, [:tenant_id, :timestamp]))
  end
end
