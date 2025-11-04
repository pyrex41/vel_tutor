defmodule ViralEngine.Metrics do
  use Ecto.Schema
  import Ecto.Changeset

  schema "metrics" do
    field(:tenant_id, Ecto.UUID)
    field(:timestamp, :utc_datetime)
    field(:task_count, :integer, default: 0)
    field(:latency_p50, :float)
    field(:latency_p95, :float)
    field(:latency_p99, :float)
    field(:total_cost, :decimal)
    field(:total_tokens, :integer, default: 0)
    field(:provider, :string)
    field(:partition_key, :date)

    timestamps()
  end

  def changeset(metrics, attrs) do
    metrics
    |> cast(attrs, [
      :tenant_id,
      :timestamp,
      :task_count,
      :latency_p50,
      :latency_p95,
      :latency_p99,
      :total_cost,
      :total_tokens,
      :provider,
      :partition_key
    ])
    |> validate_required([
      :tenant_id,
      :timestamp,
      :task_count,
      :total_cost,
      :total_tokens,
      :provider,
      :partition_key
    ])
    |> validate_number(:task_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_tokens, greater_than_or_equal_to: 0)
  end
end
