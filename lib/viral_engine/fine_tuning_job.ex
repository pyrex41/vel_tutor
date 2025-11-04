defmodule ViralEngine.FineTuningJob do
  @moduledoc """
  Fine-tuning job schema for tracking OpenAI model fine-tuning operations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "fine_tuning_jobs" do
    field(:tenant_id, Ecto.UUID)
    field(:user_id, :id)
    field(:organization_id, :binary_id)
    field(:name, :string)
    field(:training_file_id, :string)
    field(:model, :string)
    # pending, running, completed, failed
    field(:status, :string, default: "pending")
    field(:fine_tuned_model_id, :string)
    field(:cost, :decimal)
    field(:error_message, :string)

    timestamps()
  end

  @doc false
  def changeset(fine_tuning_job, attrs) do
    fine_tuning_job
    |> cast(attrs, [
      :tenant_id,
      :user_id,
      :organization_id,
      :name,
      :training_file_id,
      :model,
      :status,
      :fine_tuned_model_id,
      :cost,
      :error_message
    ])
    |> validate_required([:tenant_id, :user_id, :organization_id, :name, :model])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed"])
    |> validate_inclusion(:model, ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo-preview"])
    |> validate_number(:cost, greater_than_or_equal_to: 0)
  end
end
