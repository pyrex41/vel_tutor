defmodule ViralEngine.Integration.PerplexityAdapterTest do
  use ExUnit.Case, async: true

  alias ViralEngine.Integration.PerplexityAdapter

  describe "init/1" do
    test "initializes with Perplexity settings" do
      adapter = PerplexityAdapter.init(api_key: "test_key")
      assert adapter.api_key == "test_key"
      assert adapter.base_url == "https://api.perplexity.ai"
    end
  end
end
