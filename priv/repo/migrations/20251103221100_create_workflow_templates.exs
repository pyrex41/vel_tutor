defmodule ViralEngine.Repo.Migrations.CreateWorkflowTemplates do
  use Ecto.Migration

  def change do
    create table(:workflow_templates) do
      add(:name, :string, null: false)
      add(:description, :string)
      add(:version, :integer, default: 1, null: false)
      add(:is_public, :boolean, default: false, null: false)
      add(:template_data, :map, null: false)
      add(:created_by, :string, null: false)

      timestamps()
    end

    create(index(:workflow_templates, [:name]))
    create(index(:workflow_templates, [:is_public]))
    create(index(:workflow_templates, [:created_by]))
  end
end
