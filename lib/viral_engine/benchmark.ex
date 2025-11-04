defmodule ViralEngine.Benchmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "benchmarks" do
    field(:tenant_id, Ecto.UUID)
    field(:name, :string)
    field(:prompt, :string)
    # List of provider IDs to test
    field(:providers, {:array, :string})
    # JSONB for storing benchmark results
    field(:results, :map)
    # JSONB for statistical analysis results
    field(:stats, :map)
    # Array of historical runs
    field(:history, {:array, :map})
    # Pre-configured suite type (e.g., "code_generation")
    field(:suite, :string)

    timestamps()
  end

  def changeset(benchmark, attrs) do
    benchmark
    |> cast(attrs, [:tenant_id, :name, :prompt, :providers, :results, :stats, :history, :suite])
    |> validate_required([:tenant_id, :name, :prompt, :providers])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:prompt, min: 1, max: 10000)
    |> validate_providers()
  end

  defp validate_providers(changeset) do
    providers = get_field(changeset, :providers)

    if providers && length(providers) > 0 do
      valid_providers = ["openai", "groq", "perplexity"]
      invalid_providers = Enum.filter(providers, &(&1 not in valid_providers))

      if invalid_providers != [] do
        add_error(
          changeset,
          :providers,
          "Invalid providers: #{Enum.join(invalid_providers, ", ")}"
        )
      else
        changeset
      end
    else
      add_error(changeset, :providers, "At least one provider must be selected")
    end
  end
end
