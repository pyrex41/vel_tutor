defmodule ViralEngine.Repo.Migrations.CreateCohorts do
  use Ecto.Migration

  def change do
    create table(:cohorts) do
      add :cohort_id, :string, null: false
      add :start_date, :utc_datetime, null: false
      add :end_date, :utc_datetime, null: false
      add :filters, :map, default: %{}
      add :user_count, :integer, default: 0
      add :k_factor, :float
      add :retention_curve, :map
      add :funnel_metrics, :map
      add :ltv_delta, :decimal, precision: 10, scale: 2
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:cohorts, [:cohort_id])
    create index(:cohorts, [:start_date])
    create index(:cohorts, [:k_factor])
  end
end
