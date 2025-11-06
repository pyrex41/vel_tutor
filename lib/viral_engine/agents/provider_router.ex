defmodule ViralEngine.Agents.ProviderRouter do
  alias ViralEngine.{Provider, MetricsContext}

  @providers %{
    gpt5: %{name: "gpt-5", cost: 0.005, latency: 2000, reliability: 0.98},
    llama31: %{name: "llama-3.1", cost: 0.001, latency: 1500, reliability: 0.92}
  }

  def select_provider(criteria \\ %{}, opts \\ []) do
    providers = load_providers(opts)
    scored = Enum.map(providers, &score_provider(&1, criteria))
    best = Enum.max_by(scored, & &1.score)
    record_selection(best, criteria)
    best.provider
  end

  defp load_providers(opts) do
    if Keyword.get(opts, :from_db, true) do
      Provider.list_providers()
    else
      Map.values(@providers)
    end
  end

  defp score_provider(provider, criteria) do
    weights = Map.get(criteria, :weights, %{reliability: 0.4, cost: 0.3, performance: 0.3})

    reliability_score = provider.reliability_score * weights.reliability
    # Normalize
    cost_score = 1 / (provider.cost_per_token || 0.001) * weights.cost * 0.01
    # Normalize
    perf_score = 1 / (provider.avg_latency_ms || 1000) * weights.performance * 1000

    score = reliability_score + cost_score + perf_score
    %{provider: provider, score: score}
  end

  defp record_selection(%{provider: provider}, criteria) do
    MetricsContext.record_provider_selection(provider.id, criteria)
  end
end
