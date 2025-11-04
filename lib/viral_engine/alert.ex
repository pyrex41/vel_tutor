defmodule ViralEngine.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alerts" do
    field(:tenant_id, Ecto.UUID)
    field(:metric_type, :string)
    field(:value, :float)
    field(:threshold, :float)
    # active, resolved
    field(:status, :string, default: "active")
    field(:details, :map)
    field(:resolved_at, :naive_datetime)
    field(:resolved_by, :integer)

    timestamps()
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :tenant_id,
      :metric_type,
      :value,
      :threshold,
      :status,
      :details,
      :resolved_at,
      :resolved_by
    ])
    |> validate_required([:tenant_id, :metric_type, :value, :threshold])
    |> validate_inclusion(:status, ["active", "resolved"])
    |> validate_inclusion(:metric_type, ["error_rate", "latency", "cost_per_task", "failures"])
  end
end
