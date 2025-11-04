defmodule ViralEngine.Repo.Migrations.AddParallelExecutionFieldsToWorkflows do
  use Ecto.Migration

  def change do
    alter table(:workflows) do
      add(:parallel_groups, {:array, :map}, default: [])
      add(:execution_mode, :string, default: "sequential")
      add(:results_aggregation, :map, default: %{})
    end
  end
end
