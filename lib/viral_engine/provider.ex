defmodule ViralEngine.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "providers" do
    field(:avg_latency_ms, :integer)
    field(:cost_per_token, :decimal)
    field(:name, :string)
    field(:reliability_score, :decimal)

    timestamps()
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :cost_per_token, :avg_latency_ms, :reliability_score])
    |> validate_required([:name, :cost_per_token, :avg_latency_ms, :reliability_score])
  end
end
