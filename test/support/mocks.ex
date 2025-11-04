defmodule ViralEngine.Mocks do
  import Mox

  def mock_metrics_context do
    mock(MetricsContextMock, ViralEngine.MetricsContext, [])
  end

  def expect_record_provider_selection(provider_id, criteria) do
    expect(MetricsContextMock, :record_provider_selection, fn ^provider_id, ^criteria ->
      :ok
    end)
  end
end
