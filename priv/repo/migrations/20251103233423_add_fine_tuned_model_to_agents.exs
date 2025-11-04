defmodule ViralEngine.Repo.Migrations.AddFineTunedModelToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add(:fine_tuned_model_id, :string)
    end
  end
end
