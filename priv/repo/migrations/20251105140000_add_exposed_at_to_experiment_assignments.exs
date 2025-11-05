defmodule ViralEngine.Repo.Migrations.AddExposedAtToExperimentAssignments do
  use Ecto.Migration

  def change do
    alter table(:experiment_assignments) do
      add :exposed_at, :utc_datetime, null: true
    end

    create index(:experiment_assignments, [:exposed_at])
  end
end
