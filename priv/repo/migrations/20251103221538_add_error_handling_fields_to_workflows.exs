defmodule ViralEngine.Repo.Migrations.AddErrorHandlingFieldsToWorkflows do
  use Ecto.Migration

  def change do
    alter table(:workflows) do
      add(:retry_config, :map, default: %{})
      add(:error_categories, :map, default: %{})
      add(:rollback_steps, :map, default: %{})
      add(:notification_webhooks, {:array, :map}, default: [])
      add(:error_history, {:array, :map}, default: [])
    end
  end
end
