defmodule ViralEngine.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add(:tenant_id, :uuid, null: false)
      add(:description, :text, null: false)
      add(:agent_id, :string)
      add(:user_id, :integer)
      add(:batch_id, :integer)
      add(:status, :string, default: "pending")
      add(:result, :map, default: %{})
      add(:error_message, :text)
      add(:provider, :string)
      add(:latency_ms, :integer)
      add(:tokens_used, :integer)
      add(:cost, :decimal)
      add(:execution_history, {:array, :map}, default: [])
      add(:progress, :integer, default: 0)

      timestamps()
    end

    create(index(:tasks, [:tenant_id]))
    create(index(:tasks, [:user_id]))
    create(index(:tasks, [:batch_id]))
    create(index(:tasks, [:status]))
  end
end
