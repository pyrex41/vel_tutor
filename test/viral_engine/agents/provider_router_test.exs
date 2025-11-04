defmodule ViralEngine.Agents.ProviderRouterTest do
  use ViralEngine.DataCase

  alias ViralEngine.{Provider, Agents.ProviderRouter, MetricsContext}
  import Mox

  setup :verify_on_exit!

  describe "select_provider/2" do
    setup do
      # Seed test providers
      {:ok, gpt4o} =
        Repo.insert(%Provider{
          name: "gpt-4o",
          cost_per_token: Decimal.new("0.005"),
          avg_latency_ms: 2000,
          reliability_score: Decimal.new("0.98")
        })

      {:ok, llama} =
        Repo.insert(%Provider{
          name: "llama-3.1",
          cost_per_token: Decimal.new("0.001"),
          avg_latency_ms: 1500,
          reliability_score: Decimal.new("0.92")
        })

      %{providers: [gpt4o, llama]}
    end

    test "selects provider from static defaults when from_db: false", %{providers: _} do
      criteria = %{weights: %{reliability: 0.4, cost: 0.3, performance: 0.3}}
      provider = ProviderRouter.select_provider(criteria, from_db: false)

      assert provider.name in ["gpt-4o", "llama-3.1"]
    end

    test "selects best provider from database based on scoring", %{providers: providers} do
      # Make GPT-4o more expensive to test cost sensitivity
      Repo.update!(Provider.changeset(hd(providers), %{cost_per_token: Decimal.new("0.01")}))

      criteria = %{priority: :cost, weights: %{reliability: 0.2, cost: 0.6, performance: 0.2}}
      selected = ProviderRouter.select_provider(criteria)

      # Should select cheaper Llama 3.1
      assert selected.name == "llama-3.1"
    end

    test "prioritizes reliability when specified", %{providers: providers} do
      # Lower Llama reliability to test
      [gpt4o, llama] = providers
      Repo.update!(Provider.changeset(llama, %{reliability_score: Decimal.new("0.85")}))

      criteria = %{
        priority: :reliability,
        weights: %{reliability: 0.7, cost: 0.15, performance: 0.15}
      }

      selected = ProviderRouter.select_provider(criteria)

      assert selected.name == "gpt-4o"
    end

    test "handles fallback when no providers available" do
      # Clear providers temporarily
      Repo.delete_all(Provider)

      criteria = %{}
      selected = ProviderRouter.select_provider(criteria, from_db: false)

      assert selected.name in ["gpt-4o", "llama-3.1"]
    end

    test "records selection in metrics", %{providers: [gpt4o | _]} do
      criteria = %{priority: :performance}

      expect(MetricsContextMock, :record_provider_selection, fn provider_id, crit ->
        assert provider_id == gpt4o.id
        assert crit == criteria
        :ok
      end)

      ProviderRouter.select_provider(criteria)
    end
  end

  describe "score_provider/2" do
    test "calculates correct weighted score" do
      provider = %Provider{
        cost_per_token: Decimal.new("0.005"),
        avg_latency_ms: 2000,
        reliability_score: Decimal.new("0.98")
      }

      criteria = %{weights: %{reliability: 0.4, cost: 0.3, performance: 0.3}}
      scored = ProviderRouter.score_provider(provider, criteria)

      # Expected: (0.98 * 0.4) + (1/0.005 * 0.3 * 0.01) + (1/2000 * 0.3 * 1000)
      # = 0.392 + (200 * 0.3 * 0.01) + (0.0005 * 0.3 * 1000)
      # = 0.392 + 0.6 + 0.15 = 1.142
      assert_in_delta scored.score, 1.142, 0.01
    end
  end
end
