defmodule ViralEngine.Repo.Migrations.AddApprovalFieldsToWorkflows do
  use Ecto.Migration

  def change do
    alter table(:workflows) do
      add(:approval_gates, {:array, :map}, default: [])
      add(:approval_history, {:array, :map}, default: [])
      add(:status, :string, default: "active")
    end
  end
end
