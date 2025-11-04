defmodule ViralEngine.Integration.OpenAIAdapterTest do
  use ExUnit.Case, async: true

  alias ViralEngine.Integration.OpenAIAdapter

  describe "init/1" do
    test "initializes with default values" do
      adapter = OpenAIAdapter.init(api_key: "test_key")
      assert adapter.api_key == "test_key"
      assert adapter.base_url == "https://api.openai.com/v1"
      assert adapter.circuit_breaker_state == :closed
    end

    test "raises error without API key" do
      assert_raise RuntimeError, fn ->
        OpenAIAdapter.init([])
      end
    end
  end

  describe "chat_completion/2" do
    test "handles circuit breaker" do
      adapter = OpenAIAdapter.init(api_key: "test_key")
      # Simulate circuit breaker open
      adapter = %{
        adapter
        | circuit_breaker_state: :open,
          last_failure_time: System.system_time(:millisecond)
      }

      assert {:error, :circuit_breaker_open} =
               OpenAIAdapter.chat_completion("test", adapter: adapter)
    end
  end
end
