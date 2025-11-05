defmodule ViralEngine.Repo.Migrations.AddActivityOptOutToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :activity_opt_out, :boolean, default: false, null: false
    end

    # Add index for efficient opt-out checks
    create index(:users, [:activity_opt_out])
  end
end
