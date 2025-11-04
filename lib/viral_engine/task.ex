defmodule ViralEngine.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field(:tenant_id, Ecto.UUID)
    field(:description, :string)
    field(:agent_id, :string)
    field(:user_id, :integer)
    field(:batch_id, :integer)
    field(:status, :string, default: "pending")
    field(:result, :map, default: %{})
    field(:error_message, :string)
    field(:provider, :string)
    field(:latency_ms, :integer)
    field(:tokens_used, :integer)
    field(:cost, :decimal)
    field(:execution_history, {:array, :map}, default: [])
    field(:progress, :integer, default: 0)

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :tenant_id,
      :description,
      :agent_id,
      :user_id,
      :batch_id,
      :status,
      :result,
      :error_message,
      :provider,
      :latency_ms,
      :tokens_used,
      :cost,
      :execution_history,
      :progress
    ])
    |> validate_required([:tenant_id, :description, :agent_id, :user_id])
    |> validate_inclusion(:status, ["pending", "in_progress", "completed", "failed", "cancelled"])
  end
end
