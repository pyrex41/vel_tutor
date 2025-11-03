defmodule ViralEngine.Repo.Migrations.CreateAgentDecisions do
  use Ecto.Migration

  def change do
    create table(:agent_decisions) do
      add(:agent_id, :string, null: false)
      add(:decision_type, :string, null: false)
      add(:decision_data, :map, default: %{})
      add(:timestamp, :utc_datetime, null: false)
      add(:viral_loop_id, :string)
      add(:latency_ms, :integer)
      add(:success, :boolean, default: true)

      timestamps()
    end

    create(index(:agent_decisions, [:agent_id]))
    create(index(:agent_decisions, [:timestamp]))
    create(index(:agent_decisions, [:viral_loop_id]))
  end
end
