defmodule ViralEngine.Repo.Migrations.AddFvmTracking do
  use Ecto.Migration

  def change do
    alter table(:attribution_events) do
      add :fvm_reached, :boolean, default: false
      add :fvm_reached_at, :utc_datetime
      add :fvm_type, :string  # "diagnostic", "practice", "study"
    end

    create index(:attribution_events, [:fvm_reached])
    create index(:attribution_events, [:fvm_type])
  end
end
