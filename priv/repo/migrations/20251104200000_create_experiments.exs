defmodule ViralEngine.Repo.Migrations.CreateExperiments do
  use Ecto.Migration

  def change do
    create table(:experiments) do
      add :name, :string, null: false
      add :description, :text
      add :experiment_key, :string, null: false

      add :status, :string, default: "draft", null: false
      add :variants, :map, default: "{}"
      add :target_metric, :string
      add :success_criteria, :map, default: "{}"

      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add :traffic_allocation, :integer, default: 100

      add :metadata, :map, default: "{}"

      timestamps()
    end

    create unique_index(:experiments, [:experiment_key])
    create index(:experiments, [:status])

    create table(:experiment_assignments) do
      add :experiment_id, :integer, null: false
      add :user_id, :integer, null: false
      add :variant, :string, null: false

      add :assigned_at, :utc_datetime, null: false
      add :converted, :boolean, default: false
      add :conversion_value, :decimal
      add :conversion_at, :utc_datetime

      add :metrics, :map, default: "{}"

      timestamps()
    end

    create unique_index(:experiment_assignments, [:experiment_id, :user_id])
    create index(:experiment_assignments, [:user_id])
    create index(:experiment_assignments, [:variant])
    create index(:experiment_assignments, [:converted])
  end
end
