defmodule ViralEngine.WorkflowTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_templates" do
    field(:name, :string)
    field(:description, :string)
    field(:version, :integer, default: 1)
    field(:is_public, :boolean, default: false)
    field(:template_data, :map)
    field(:created_by, :string)

    timestamps()
  end

  def changeset(workflow_template, attrs) do
    workflow_template
    |> cast(attrs, [:name, :description, :version, :is_public, :template_data, :created_by])
    |> validate_required([:name, :template_data, :created_by])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, min: 0, max: 1000)
    |> validate_number(:version, greater_than: 0)
  end
end
