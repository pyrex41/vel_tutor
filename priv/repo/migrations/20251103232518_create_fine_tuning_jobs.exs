defmodule ViralEngine.Repo.Migrations.CreateFineTuningJobs do
  use Ecto.Migration

  def change do
    create table(:fine_tuning_jobs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:tenant_id, :binary_id, null: false)
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all))
      add(:name, :string, null: false)
      add(:training_file_id, :string)
      add(:model, :string, null: false)
      add(:status, :string, default: "pending", null: false)
      add(:fine_tuned_model_id, :string)
      add(:cost, :decimal)
      add(:error_message, :text)

      timestamps()
    end

    create(index(:fine_tuning_jobs, [:tenant_id]))
    create(index(:fine_tuning_jobs, [:user_id]))
    create(index(:fine_tuning_jobs, [:organization_id]))
    create(index(:fine_tuning_jobs, [:status]))
  end
end
