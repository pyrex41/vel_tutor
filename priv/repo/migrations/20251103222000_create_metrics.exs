defmodule ViralEngine.Repo.Migrations.CreateMetrics do
  use Ecto.Migration

  def change do
    create table(:metrics) do
      add(:timestamp, :utc_datetime, null: false)
      add(:task_count, :integer, default: 0, null: false)
      add(:latency_p50, :float)
      add(:latency_p95, :float)
      add(:latency_p99, :float)
      add(:total_cost, :decimal, precision: 10, scale: 4, null: false)
      add(:total_tokens, :integer, default: 0, null: false)
      add(:provider, :string, null: false)
      add(:partition_key, :date, null: false)

      timestamps()
    end

    # Create indexes for efficient querying
    create(index(:metrics, [:timestamp]))
    create(index(:metrics, [:provider]))
    create(index(:metrics, [:partition_key]))
  end
end
