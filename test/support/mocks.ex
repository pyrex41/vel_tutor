defmodule ViralEngine.Mocks do
  import Mox

  def mock_metrics_context do
    # Mock is already defined in test_helper.exs
    :ok
  end

  def expect_record_provider_selection(provider_id, criteria) do
    expect(ViralEngine.MetricsContextMock, :record_provider_selection, fn ^provider_id,
                                                                          ^criteria ->
      :ok
    end)
  end
end
