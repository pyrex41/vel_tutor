defmodule ViralEngine.Repo.Migrations.CreateAiProviders do
  use Ecto.Migration

  def change do
    create table(:ai_providers) do
      add :name, :string, null: false
      add :provider_type, :string, null: false # openai, groq, perplexity
      add :model, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :priority, :integer, default: 0, null: false # Higher priority = preferred
      add :cost_per_1m_tokens, :decimal, precision: 10, scale: 4
      add :avg_latency_ms, :integer
      add :reliability_score, :decimal, precision: 3, scale: 2
      add :max_retries, :integer, default: 3
      add :timeout_ms, :integer, default: 30000
      add :config, :map # JSON config for provider-specific settings

      timestamps()
    end

    create unique_index(:ai_providers, [:provider_type, :model])
    create index(:ai_providers, [:enabled])
    create index(:ai_providers, [:priority])

    # Seed initial providers from config/ai.exs
    execute(&seed_providers/0, &rollback_providers/0)
  end

  defp seed_providers do
    repo().insert_all("ai_providers", [
      # OpenAI Providers
      %{
        name: "OpenAI GPT-4o",
        provider_type: "openai",
        model: "gpt-4o",
        enabled: true,
        priority: 100,
        cost_per_1m_tokens: Decimal.new("6.25"),
        avg_latency_ms: 2100,
        reliability_score: Decimal.new("0.98"),
        max_retries: 3,
        timeout_ms: 30_000,
        config: %{},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        name: "OpenAI GPT-4o-mini",
        provider_type: "openai",
        model: "gpt-4o-mini",
        enabled: true,
        priority: 90,
        cost_per_1m_tokens: Decimal.new("0.37"),
        avg_latency_ms: 1500,
        reliability_score: Decimal.new("0.98"),
        max_retries: 3,
        timeout_ms: 30_000,
        config: %{},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Groq Providers
      %{
        name: "Groq Llama 3.3 70B Versatile",
        provider_type: "groq",
        model: "llama-3.3-70b-versatile",
        enabled: true,
        priority: 95,
        cost_per_1m_tokens: Decimal.new("0.69"),
        avg_latency_ms: 300,
        reliability_score: Decimal.new("0.95"),
        max_retries: 3,
        timeout_ms: 10_000,
        config: %{},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        name: "Groq Llama 3.1 70B Versatile",
        provider_type: "groq",
        model: "llama-3.1-70b-versatile",
        enabled: true,
        priority: 85,
        cost_per_1m_tokens: Decimal.new("0.59"),
        avg_latency_ms: 250,
        reliability_score: Decimal.new("0.95"),
        max_retries: 3,
        timeout_ms: 10_000,
        config: %{},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },
      %{
        name: "Groq Mixtral 8x7B",
        provider_type: "groq",
        model: "mixtral-8x7b-32768",
        enabled: true,
        priority: 80,
        cost_per_1m_tokens: Decimal.new("0.24"),
        avg_latency_ms: 200,
        reliability_score: Decimal.new("0.94"),
        max_retries: 3,
        timeout_ms: 10_000,
        config: %{},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      },

      # Perplexity Providers (stubbed for future use)
      %{
        name: "Perplexity Sonar Large Online",
        provider_type: "perplexity",
        model: "sonar-large-online",
        enabled: false, # Disabled per user request
        priority: 70,
        cost_per_1m_tokens: Decimal.new("1.0"),
        avg_latency_ms: 3200,
        reliability_score: Decimal.new("0.96"),
        max_retries: 3,
        timeout_ms: 30_000,
        config: %{cache_ttl: 86_400},
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])
  end

  defp rollback_providers do
    repo().delete_all("ai_providers")
  end
end
