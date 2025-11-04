defmodule ViralEngine.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "providers" do
    field(:avg_latency_ms, :integer, null: false)
    field(:cost_per_token, :decimal, null: false)
    field(:name, :string, null: false)
    field(:reliability_score, :decimal, null: false)

    timestamps()
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :cost_per_token, :avg_latency_ms, :reliability_score])
    |> validate_required([:name, :cost_per_token, :avg_latency_ms, :reliability_score])
  end
end
