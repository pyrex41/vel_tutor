defmodule ViralEngine.Workflow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflows" do
    field(:tenant_id, Ecto.UUID)
    field(:name, :string)
    field(:state, :map)
    field(:version, :integer, default: 1)
    field(:routing_rules, {:array, :map}, default: [])
    field(:conditions, {:array, :map}, default: [])
    field(:approval_gates, {:array, :map}, default: [])
    field(:approval_history, {:array, :map}, default: [])
    field(:status, :string, default: "active")
    field(:parallel_groups, {:array, :map}, default: [])
    field(:execution_mode, :string, default: "sequential")
    field(:results_aggregation, :map, default: %{})
    field(:retry_config, :map, default: %{})
    field(:error_categories, :map, default: %{})
    field(:rollback_steps, :map, default: %{})
    field(:notification_webhooks, {:array, :map}, default: [])
    field(:error_history, {:array, :map}, default: [])

    timestamps()
  end

  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [
      :tenant_id,
      :name,
      :state,
      :version,
      :routing_rules,
      :conditions,
      :approval_gates,
      :approval_history,
      :status,
      :parallel_groups,
      :execution_mode,
      :results_aggregation,
      :retry_config,
      :error_categories,
      :rollback_steps,
      :notification_webhooks,
      :error_history
    ])
    |> validate_required([:tenant_id, :name, :state])
    |> validate_number(:version, greater_than: 0)
    |> validate_inclusion(:status, [
      "active",
      "awaiting_approval",
      "approved",
      "rejected",
      "timed_out",
      "failed"
    ])
    |> validate_inclusion(:execution_mode, ["sequential", "parallel"])
  end
end
